defmodule LucaWebapp.Appointments.PendingBooking do
  use Ecto.Schema

  import Ecto.Changeset

  alias LucaWebapp.Appointments.Booking

  schema "pending_bookings" do
    field :status, :string
    field :tracked_at, :utc_datetime
    belongs_to :booking, Booking

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(pending_booking, attrs) do
    pending_booking
    |> cast(attrs, [:booking_id, :status, :tracked_at])
    |> validate_required([:booking_id, :status, :tracked_at])
    |> validate_inclusion(:status, ["booking"])
    |> check_constraint(:status, name: :pending_bookings_status_allowed)
    |> foreign_key_constraint(:booking_id)
    |> unique_constraint(:booking_id)
  end
end
