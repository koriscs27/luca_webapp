defmodule LucaWebapp.AppointmentsTest do
  use LucaWebapp.DataCase, async: false

  alias LucaWebapp.Appointments
  alias LucaWebapp.Appointments.Booking
  alias LucaWebapp.Appointments.PendingBooking
  alias LucaWebapp.Repo

  @base_time ~U[2026-02-03 10:00:00Z]

  defp attrs_for_window(starts_at, ends_at, name \\ "Alex Doe") do
    %{
      "name" => name,
      "appointment_type" => "Consultation",
      "starts_at" => starts_at,
      "ends_at" => ends_at
    }
  end

  defp run_concurrent(fun_list) do
    owner = self()

    fun_list
    |> Task.async_stream(
      fn fun ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, owner, self())
        fun.()
      end,
      max_concurrency: length(fun_list),
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  test "simple insert works with an appointment" do
    starts_at = @base_time
    ends_at = DateTime.add(starts_at, 3600, :second)

    assert {:ok, booking} = Appointments.create_booking(attrs_for_window(starts_at, ends_at))
    assert booking.name == "Alex Doe"
    assert booking.appointment_type == "Consultation"
    assert booking.starts_at == starts_at
    assert booking.ends_at == ends_at
    assert booking.status == "booked"
    refute is_nil(booking.booking_id)

    assert Repo.aggregate(PendingBooking, :count) == 0
  end

  test "payment failures set booking as rejected and clean pending records" do
    starts_at = DateTime.add(@base_time, 14_400, :second)
    ends_at = DateTime.add(starts_at, 3600, :second)

    assert {:ok, booking} =
             Appointments.create_booking(
               attrs_for_window(starts_at, ends_at),
               fn _booking -> {:error, :payment_failed} end
             )

    assert booking.status == "rejected"
    assert Repo.aggregate(PendingBooking, :count) == 0
  end

  test "rejected bookings do not block future bookings for the same window" do
    starts_at = DateTime.add(@base_time, 18_000, :second)
    ends_at = DateTime.add(starts_at, 3600, :second)

    assert {:ok, rejected_booking} =
             Appointments.create_booking(
               attrs_for_window(starts_at, ends_at, "Rejected Person"),
               fn _booking -> {:error, :payment_failed} end
             )

    assert rejected_booking.status == "rejected"

    assert {:ok, booked_booking} =
             Appointments.create_booking(attrs_for_window(starts_at, ends_at, "Booked Person"))

    assert booked_booking.status == "booked"
  end

  test "non-overlapping appointments can be booked concurrently" do
    starts_at_1 = DateTime.add(@base_time, 0, :second)
    ends_at_1 = DateTime.add(starts_at_1, 3600, :second)
    starts_at_2 = DateTime.add(@base_time, 7200, :second)
    ends_at_2 = DateTime.add(starts_at_2, 3600, :second)

    results =
      run_concurrent([
        fn -> Appointments.create_booking(attrs_for_window(starts_at_1, ends_at_1)) end,
        fn -> Appointments.create_booking(attrs_for_window(starts_at_2, ends_at_2)) end
      ])

    assert Enum.all?(results, &match?({:ok, _}, &1))
  end

  test "overlapping appointments allow only one success across concurrent attempts" do
    Enum.each(1..15, fn iteration ->
      starts_at = DateTime.add(@base_time, iteration * 7200, :second)
      ends_at = DateTime.add(starts_at, 3600, :second)
      names = ["Client A", "Client B", "Client C"]

      results =
        run_concurrent([
          fn ->
            Appointments.create_booking(attrs_for_window(starts_at, ends_at, Enum.at(names, 0)))
          end,
          fn ->
            Appointments.create_booking(attrs_for_window(starts_at, ends_at, Enum.at(names, 1)))
          end,
          fn ->
            Appointments.create_booking(attrs_for_window(starts_at, ends_at, Enum.at(names, 2)))
          end
        ])

      successes = Enum.filter(results, &match?({:ok, _}, &1))
      errors = Enum.filter(results, &match?({:error, _}, &1))
      assert length(successes) == 1
      assert length(errors) == 2

      [{:ok, booking}] = successes
      persisted = Appointments.get_booking!(booking.id)
      assert persisted.name == booking.name

      Enum.each(errors, fn {:error, changeset} ->
        assert "overlaps with another booking" in errors_on(changeset).starts_at
      end)
    end)
  end

  test "cleanup_stale_pending_bookings removes stuck booking records older than threshold" do
    stale_booking =
      %Booking{}
      |> Booking.changeset(
        attrs_for_window(
          DateTime.add(@base_time, 40_000, :second),
          DateTime.add(@base_time, 43_600, :second),
          "Stale Client"
        )
      )
      |> Booking.put_initial_state()
      |> Repo.insert!()

    stale_pending =
      %PendingBooking{}
      |> PendingBooking.changeset(%{
        booking_id: stale_booking.id,
        status: "booking",
        tracked_at: DateTime.add(DateTime.utc_now(), -700, :second)
      })
      |> Repo.insert!()

    summary = Appointments.cleanup_stale_pending_bookings(600)

    assert summary.pending_deleted == 1
    assert summary.bookings_deleted == 1
    assert Repo.get(Booking, stale_booking.id) == nil
    assert Repo.get(PendingBooking, stale_pending.id) == nil
  end
end
