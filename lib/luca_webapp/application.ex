defmodule LucaWebapp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    booking_cleanup_children =
      if Application.get_env(:luca_webapp, :booking_cleanup_enabled, true) do
        [LucaWebapp.Appointments.StalePendingBookingsCleaner]
      else
        []
      end

    children =
      [
        LucaWebappWeb.Telemetry,
        LucaWebapp.Repo,
        {DNSCluster, query: Application.get_env(:luca_webapp, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: LucaWebapp.PubSub}
        # Start a worker by calling: LucaWebapp.Worker.start_link(arg)
        # {LucaWebapp.Worker, arg}
      ] ++
        booking_cleanup_children ++
        [
          # Start to serve requests, typically the last entry
          LucaWebappWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LucaWebapp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LucaWebappWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
