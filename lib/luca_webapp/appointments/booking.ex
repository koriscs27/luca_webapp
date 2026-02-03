defmodule LucaWebapp.Appointments.Booking do
  use Ecto.Schema

  import Ecto.Changeset

  schema "bookings" do
    field :name, :string
    field :appointment_type, :string
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
    |> exclusion_constraint(:starts_at,
      name: :bookings_no_overlap,
      message: "overlaps with another booking"
    )
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
