defmodule LucaWebapp.Repo.Migrations.DropBookingsNoOverlapConstraint do
  use Ecto.Migration

  def change do
    drop constraint(:bookings, :bookings_no_overlap)
  end
end
