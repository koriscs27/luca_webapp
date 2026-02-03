defmodule LucaWebapp.AppointmentsTest do
  use LucaWebapp.DataCase, async: false

  alias LucaWebapp.Appointments
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
      IO.inspect(successes, label: "Returned ok")
      assert length(successes) == 1

      [{:ok, booking}] = successes
      persisted = Appointments.get_booking!(booking.id)
      IO.inspect(persisted, label: "From db")
      assert persisted.name == booking.name
    end)
  end
end
