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
      Pinchflat.Boot.PreJobStartupTasks,
      {Oban, Application.fetch_env!(:pinchflat, Oban)},
      Pinchflat.Boot.PostJobStartupTasks,
      {DNSCluster, query: Application.get_env(:pinchflat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pinchflat.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Pinchflat.Finch},
      # Start a worker by calling: Pinchflat.Worker.start_link(arg)
      # {Pinchflat.Worker, arg},
      # Start to serve requests, typically the last entry
      PinchflatWeb.Endpoint
    ]

    attach_oban_telemetry()
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

  defp attach_oban_telemetry do
    events = [[:oban, :job, :start], [:oban, :job, :stop], [:oban, :job, :exception]]

    :ok = Oban.Telemetry.attach_default_logger()
    :telemetry.attach_many("job-telemetry-broadcast", events, &PinchflatWeb.Telemetry.job_state_change_broadcast/4, [])
  end
end
