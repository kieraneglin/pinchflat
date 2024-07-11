# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :pinchflat,
  ecto_repos: [Pinchflat.Repo],
  generators: [timestamp_type: :utc_datetime],
  # Specifying backend data here makes mocking and local testing SUPER easy
  yt_dlp_executable: System.find_executable("yt-dlp"),
  apprise_executable: System.find_executable("apprise"),
  yt_dlp_runner: Pinchflat.YtDlp.CommandRunner,
  apprise_runner: Pinchflat.Lifecycle.Notifications.CommandRunner,
  media_directory: "/downloads",
  # The user may or may not store metadata for their needs, but the app will always store its copy
  metadata_directory: "/config/metadata",
  extras_directory: "/config/extras",
  tmpfile_directory: Path.join([System.tmp_dir!(), "pinchflat", "data"]),
  # Setting BASIC_AUTH_USERNAME and BASIC_AUTH_PASSWORD implies you want to use basic auth.
  # If either is unset, basic auth will not be used.
  basic_auth_username: "",
  basic_auth_password: "",
  expose_feed_endpoints: false,
  file_watcher_poll_interval: 1000,
  timezone: "UTC",
  base_route_path: "/"

config :pinchflat, Pinchflat.Repo,
  journal_mode: :wal,
  pool_size: 5

# Configures the endpoint
config :pinchflat, PinchflatWeb.Endpoint,
  url: [host: "localhost", port: 8945],
  # NOTE: this must be updated if ever deployed traditionally (ie: not self-hosted)
  check_origin: false,
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PinchflatWeb.ErrorHTML, json: PinchflatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Pinchflat.PubSub,
  live_view: [signing_salt: "/t5878kO"]

config :pinchflat, Oban,
  engine: Oban.Engines.Lite,
  repo: Pinchflat.Repo,
  # Keep old jobs for 30 days for display in the UI
  plugins: [
    {Oban.Plugins.Pruner, max_age: 30 * 24 * 60 * 60},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 1 * * *", Pinchflat.Downloading.MediaRetentionWorker},
       {"0 2 * * *", Pinchflat.Downloading.MediaQualityUpgradeWorker}
     ]}
  ],
  # TODO: consider making this an env var or something?
  queues: [
    default: 10,
    fast_indexing: 6,
    media_indexing: 2,
    media_collection_indexing: 2,
    media_fetching: 2,
    local_metadata: 8,
    remote_metadata: 4
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :pinchflat, Pinchflat.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time $metadata[$level] | $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
