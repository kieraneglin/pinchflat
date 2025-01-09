defmodule Pinchflat.PromEx do
  @moduledoc """
  Configuration for the PromEx library which provides Prometheus metrics
  """

  use PromEx, otp_app: :pinchflat

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: PinchflatWeb.Router, endpoint: PinchflatWeb.Endpoint},
      Plugins.Ecto,
      Plugins.Oban,
      Plugins.PhoenixLiveView
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"},
      {:prom_ex, "phoenix_live_view.json"}
    ]
  end
end
