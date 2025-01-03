defmodule PinchflatWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :pinchflat

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_pinchflat_key",
    signing_salt: "3hKEgjXG",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :pinchflat,
    gzip: Mix.env() == :prod,
    only: PinchflatWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :pinchflat
  end

  plug PromEx.Plug, prom_ex_module: Pinchflat.PromEx

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug :override_base_url
  plug :strip_trailing_extension

  plug PinchflatWeb.Router

  # URLs need to be generated using the host of the current page being accessed
  # for things like Podcast RSS feeds to contain links to the right location.
  #
  # Normally you'd set the `url` option in the Endpoint configuration, but
  # since this is self-hosted and often accessed at multiple different URLs,
  # that would probably be more difficult for end-users to set up than just
  # having the application figure it out.
  defp override_base_url(conn, _opts) do
    new_scheme =
      case get_req_header(conn, "x-forwarded-proto") do
        [scheme] -> scheme
        _ -> to_string(conn.scheme)
      end

    new_port = if conn.port in [80, 443], do: "", else: ":#{conn.port}"
    new_base_url = "#{new_scheme}://#{conn.host}#{new_port}"

    Phoenix.Controller.put_router_url(conn, new_base_url)
  end

  # Some podcast clients require file extensions, and others still will _add_
  # file extensions to XML files if they don't have them. This plug removes
  # the extension from the path so that the correct route is matched, regardless
  # of the provided extension.
  #
  # This has the downside of in-app generated verified routes not working with
  # extensions so this behaviour may change in the future.
  defp strip_trailing_extension(%{path_info: []} = conn, _opts), do: conn

  defp strip_trailing_extension(conn, _opts) do
    path =
      conn.path_info
      |> List.last()
      |> String.split(".")
      |> Enum.reverse()

    case path do
      [_] ->
        conn

      [_format | fragments] ->
        new_path =
          fragments
          |> Enum.reverse()
          |> Enum.join(".")

        path_fragments = List.replace_at(conn.path_info, -1, new_path)

        %{conn | path_info: path_fragments}
    end
  end
end
