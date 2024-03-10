defmodule Pinchflat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PinchflatWeb.Telemetry,
      Pinchflat.Repo,
      # Must be before startup tasks
      {Oban, Application.fetch_env!(:pinchflat, Oban)},
      Pinchflat.StartupTasks,
      {DNSCluster, query: Application.get_env(:pinchflat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pinchflat.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Pinchflat.Finch},
      # Start a worker by calling: Pinchflat.Worker.start_link(arg)
      # {Pinchflat.Worker, arg},
      # Start to serve requests, typically the last entry
      PinchflatWeb.Endpoint
    ]

    :ok = Oban.Telemetry.attach_default_logger()
    Logger.add_handlers(:pinchflat)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pinchflat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PinchflatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
