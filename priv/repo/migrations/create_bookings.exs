defmodule LucaWebapp.Repo.Migrations.CreateBookings do
  use Ecto.Migration

  def change do
    create table(:bookings) do
      add :name, :string, null: false
      add :appointment_type, :string, null: false
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:bookings, :bookings_ends_after_starts, check: "ends_at > starts_at")

    execute("""
    ALTER TABLE bookings
    ADD CONSTRAINT bookings_no_overlap
    EXCLUDE USING gist (tsrange(starts_at, ends_at, '[)') WITH &&)
    """)
  end
end
