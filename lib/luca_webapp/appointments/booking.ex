defmodule LucaWebapp.Appointments.Booking do
  use Ecto.Schema

  import Ecto.Changeset

  @statuses ["booking", "booked", "rejected"]

  schema "bookings" do
    field :booking_id, :string
    field :name, :string
    field :appointment_type, :string
    field :status, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [:name, :appointment_type, :starts_at, :ends_at])
    |> validate_required([:name, :appointment_type, :starts_at, :ends_at])
    |> validate_length(:name, max: 200)
    |> validate_length(:appointment_type, max: 200)
    |> validate_starts_before_ends()
    |> check_constraint(:ends_at, name: :bookings_ends_after_starts)
    |> check_constraint(:status, name: :bookings_status_allowed)
    |> unique_constraint(:booking_id)
  end

  def add_overlap_error(changeset) do
    add_error(changeset, :starts_at, "overlaps with another booking")
  end

  def put_initial_state(changeset) do
    changeset
    |> put_change(:booking_id, Ecto.UUID.generate())
    |> put_change(:status, "booking")
    |> validate_required([:booking_id, :status])
    |> validate_inclusion(:status, @statuses)
  end

  def status_changeset(booking, status) do
    booking
    |> change(status: status)
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end

  defp validate_starts_before_ends(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && ends_at <= starts_at do
      add_error(changeset, :ends_at, "must be after the start time")
    else
      changeset
    end
  end
end
