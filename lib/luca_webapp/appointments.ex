defmodule LucaWebapp.Appointments do
  import Ecto.Query, warn: false

  alias LucaWebapp.Repo
  alias LucaWebapp.Appointments.Booking
  alias LucaWebapp.Appointments.PendingBooking

  @booking_lock_key 1_001

  def list_bookings do
    Repo.all(from b in Booking, order_by: [asc: b.starts_at])
  end

  def get_booking!(id), do: Repo.get!(Booking, id)

  def create_booking(attrs \\ %{}, payment_fun \\ &simulate_payment/1)
      when is_function(payment_fun, 1) do
    changeset =
      %Booking{}
      |> Booking.changeset(attrs)
      |> Booking.put_initial_state()

    if changeset.valid? do
      with {:ok, booking} <- create_booking_with_lock(changeset),
           {:ok, finalized_booking} <- finalize_booking(booking, payment_fun) do
        {:ok, finalized_booking}
      end
    else
      {:error, changeset}
    end
  end

  defp create_booking_with_lock(changeset) do
    starts_at = Ecto.Changeset.get_field(changeset, :starts_at)
    ends_at = Ecto.Changeset.get_field(changeset, :ends_at)

    case Repo.transaction(fn ->
           Repo.query!("SELECT pg_advisory_xact_lock($1)", [@booking_lock_key])

           if booking_overlaps?(starts_at, ends_at) do
             Repo.rollback(Booking.add_overlap_error(changeset))
           else
             case Repo.insert(changeset) do
               {:ok, booking} ->
                 case create_pending_booking(booking) do
                   {:ok, _pending_booking} -> booking
                   {:error, pending_changeset} -> Repo.rollback(pending_changeset)
                 end

               {:error, insert_changeset} ->
                 Repo.rollback(insert_changeset)
             end
           end
         end) do
      {:ok, booking} -> {:ok, booking}
      {:error, rollback_reason} -> {:error, rollback_reason}
    end
  end

  defp booking_overlaps?(starts_at, ends_at) do
    Booking
    |> where([b], b.status in ["booking", "booked"])
    |> where([b], b.starts_at < ^ends_at and b.ends_at > ^starts_at)
    |> Repo.exists?()
  end

  def cleanup_stale_pending_bookings(stale_after_seconds \\ stale_booking_age_seconds()) do
    cutoff = DateTime.add(DateTime.utc_now(), -stale_after_seconds, :second)

    stale_entries =
      PendingBooking
      |> where([p], p.status == "booking" and p.tracked_at < ^cutoff)
      |> Repo.all()

    Enum.reduce(stale_entries, %{pending_deleted: 0, bookings_deleted: 0}, fn pending_booking,
                                                                              acc ->
      result =
        Repo.transaction(fn ->
          booking = Repo.get(Booking, pending_booking.booking_id)

          delete_pending_booking!(pending_booking)

          if booking && booking.status == "booking" do
            Repo.delete!(booking)
            %{pending_deleted: 1, bookings_deleted: 1}
          else
            %{pending_deleted: 1, bookings_deleted: 0}
          end
        end)

      case result do
        {:ok, counters} ->
          %{
            pending_deleted: acc.pending_deleted + counters.pending_deleted,
            bookings_deleted: acc.bookings_deleted + counters.bookings_deleted
          }

        {:error, _reason} ->
          acc
      end
    end)
  end

  def stale_booking_age_seconds do
    Application.get_env(:luca_webapp, :booking_stale_after_seconds, 600)
  end

  defp create_pending_booking(booking) do
    pending_attrs = %{
      booking_id: booking.id,
      status: booking.status,
      tracked_at: DateTime.utc_now()
    }

    %PendingBooking{}
    |> PendingBooking.changeset(pending_attrs)
    |> Repo.insert()
  end

  defp finalize_booking(booking, payment_fun) do
    target_status =
      case payment_fun.(booking) do
        :ok -> "booked"
        {:ok, _result} -> "booked"
        _ -> "rejected"
      end

    Repo.transaction(fn ->
      booking = Repo.get!(Booking, booking.id)

      case booking |> Booking.status_changeset(target_status) |> Repo.update() do
        {:ok, updated_booking} ->
          PendingBooking
          |> where([p], p.booking_id == ^updated_booking.id and p.status == "booking")
          |> Repo.delete_all()

          updated_booking

        {:error, update_changeset} ->
          Repo.rollback(update_changeset)
      end
    end)
    |> case do
      {:ok, updated_booking} -> {:ok, updated_booking}
      {:error, reason} -> {:error, reason}
    end
  end

  defp simulate_payment(_booking), do: :ok

  defp delete_pending_booking!(pending_booking) do
    repo_pending_booking = Repo.get!(PendingBooking, pending_booking.id)
    Repo.delete!(repo_pending_booking)
  end
end
