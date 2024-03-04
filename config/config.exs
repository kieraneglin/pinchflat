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
  yt_dlp_runner: Pinchflat.MediaClient.Backends.YtDlp.CommandRunner,
  media_directory: "/downloads",
  # The user may or may not store metadata for their needs, but the app will always store its copy
  metadata_directory: "/config/metadata",
  tmpfile_directory: Path.join([System.tmp_dir!(), "pinchflat", "data"]),
  # Setting AUTH_USERNAME and AUTH_PASSWORD implies you want to use basic auth.
  # If either is unset, basic auth will not be used.
  basic_auth_username: System.get_env("AUTH_USERNAME"),
  basic_auth_password: System.get_env("AUTH_PASSWORD"),
  file_watcher_poll_interval: 1000

# Configures the endpoint
config :pinchflat, PinchflatWeb.Endpoint,
  url: [host: "localhost", port: 8945],
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
  plugins: [{Oban.Plugins.Pruner, max_age: 30 * 24 * 60 * 60}],
  # TODO: consider making this an env var or something?
  queues: [default: 10, media_indexing: 2, media_fetching: 2, media_local_metadata: 8]

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
  version: "3.3.2",
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
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
