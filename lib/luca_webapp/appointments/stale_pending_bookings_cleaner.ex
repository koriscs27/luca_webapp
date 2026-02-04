defmodule LucaWebapp.Appointments.StalePendingBookingsCleaner do
  use GenServer

  require Logger

  alias LucaWebapp.Appointments

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{interval_ms: cleanup_interval_ms()}
    schedule_cleanup(state.interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    summary = Appointments.cleanup_stale_pending_bookings()

    Logger.debug(
      "Stale booking cleanup completed: pending_deleted=#{summary.pending_deleted}, bookings_deleted=#{summary.bookings_deleted}"
    )

    schedule_cleanup(state.interval_ms)
    {:noreply, state}
  end

  defp schedule_cleanup(interval_ms) do
    Process.send_after(self(), :cleanup, interval_ms)
  end

  defp cleanup_interval_ms do
    Application.get_env(:luca_webapp, :pending_booking_cleanup_interval_ms, :timer.minutes(10))
  end
end
