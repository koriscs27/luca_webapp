defmodule LucaWebapp.Appointments do
  import Ecto.Query, warn: false

  alias LucaWebapp.Repo
  alias LucaWebapp.Appointments.Booking

  def list_bookings do
    Repo.all(from b in Booking, order_by: [asc: b.starts_at])
  end

  def get_booking!(id), do: Repo.get!(Booking, id)

  def create_booking(attrs \\ %{}) do
    %Booking{}
    |> Booking.changeset(attrs)
    |> Repo.insert()
  end
end
