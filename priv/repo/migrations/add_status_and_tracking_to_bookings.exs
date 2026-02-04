defmodule LucaWebapp.Repo.Migrations.AddStatusAndTrackingToBookings do
  use Ecto.Migration

  def change do
    alter table(:bookings) do
      add :booking_id, :string
      add :status, :string, null: false, default: "booking"
    end

    create unique_index(:bookings, [:booking_id])
    create index(:bookings, [:status])

    create constraint(:bookings, :bookings_status_allowed,
             check: "status IN ('booking', 'booked', 'rejected')"
           )

    execute("UPDATE bookings SET booking_id = id::text WHERE booking_id IS NULL")

    alter table(:bookings) do
      modify :booking_id, :string, null: false
    end

    create table(:pending_bookings) do
      add :booking_id, references(:bookings, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :tracked_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:pending_bookings, [:booking_id])
    create index(:pending_bookings, [:status, :tracked_at])

    create constraint(:pending_bookings, :pending_bookings_status_allowed,
             check: "status = 'booking'"
           )
  end
end
