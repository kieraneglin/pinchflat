import Config
require Logger

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/pinchflat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :pinchflat, PinchflatWeb.Endpoint, server: true
end

config :pinchflat,
  basic_auth_username: System.get_env("BASIC_AUTH_USERNAME"),
  basic_auth_password: System.get_env("BASIC_AUTH_PASSWORD")

arch_string = to_string(:erlang.system_info(:system_architecture))

system_arch =
  cond do
    String.contains?(arch_string, "arm") -> "arm"
    String.contains?(arch_string, "aarch") -> "arm"
    String.contains?(arch_string, "x86") -> "x86"
    true -> "unknown"
  end

config :pinchflat, Pinchflat.Repo,
  load_extensions: [
    Path.join([:code.priv_dir(:pinchflat), "repo", "extensions", "sqlean-linux-#{system_arch}", "sqlean"])
  ]

if config_env() == :prod do
  config_path = "/config"
  db_path = System.get_env("DATABASE_PATH", Path.join([config_path, "db", "pinchflat.db"]))
  log_path = System.get_env("LOG_PATH", Path.join([config_path, "logs", "pinchflat.log"]))
  metadata_path = System.get_env("METADATA_PATH", Path.join([config_path, "metadata"]))
  extras_path = System.get_env("EXTRAS_PATH", Path.join([config_path, "extras"]))

  # For running PF as a podcast host on self-hosted environments
  expose_feed_endpoints = String.length(System.get_env("EXPOSE_FEED_ENDPOINTS", "")) > 0

  # We want to force _some_ level of useful logging in production
  acceptable_log_levels = ~w(debug info)a
  log_level = String.to_existing_atom(System.get_env("LOG_LEVEL", "info"))

  if log_level in acceptable_log_levels do
    config :logger, level: log_level
  else
    Logger.error("Invalid log level: #{log_level}. Defaulting to info.")
    config :logger, level: :info
  end

  config :pinchflat,
    yt_dlp_executable: System.find_executable("yt-dlp"),
    media_directory: "/downloads",
    metadata_directory: metadata_path,
    extras_directory: extras_path,
    tmpfile_directory: Path.join([System.tmp_dir!(), "pinchflat", "data"]),
    dns_cluster_query: System.get_env("DNS_CLUSTER_QUERY"),
    expose_feed_endpoints: expose_feed_endpoints

  config :pinchflat, Pinchflat.Repo,
    database: db_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    if System.get_env("SECRET_KEY_BASE") do
      System.get_env("SECRET_KEY_BASE")
    else
      if System.get_env("RUN_CONTEXT") == "selfhosted" do
        # Using the default SECRET_KEY_BASE in a conventional production environment
        # is dangerous. Please set the SECRET_KEY_BASE environment variable if you're
        # deploying this to an internet-facing server. If you're running this in a
        # private network, it's likely safe to use the default value. If you want
        # to be extra safe, run `mix phx.gen.secret` and set the SECRET_KEY_BASE
        # environment variable to the output of that command.

        "ZkuQMStdmUzBv+gO3m3XZrtQW76e+AX3QIgTLajw3b/HkTLMEx+DOXr2WZsSS+n8"
      else
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """
      end
    end

  config :pinchflat, PinchflatWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  config :pinchflat, :logger, [
    {:handler, :file_log, :logger_std_h,
     %{
       config: %{
         type: :file,
         file: String.to_charlist(log_path),
         filesync_repeat_interval: 5000,
         file_check: 5000,
         max_no_files: 5,
         max_no_bytes: 10_000_000
       },
       formatter: Logger.Formatter.new()
     }}
  ]
end
