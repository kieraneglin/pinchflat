import Config

config :pinchflat,
  # Specifying backend data here makes mocking and local testing SUPER easy
  yt_dlp_executable: Path.join([File.cwd!(), "/test/support/scripts/yt-dlp-mocks/repeater.sh"]),
  media_directory: Path.join([System.tmp_dir!(), "test", "media"]),
  metadata_directory: Path.join([System.tmp_dir!(), "test", "metadata"]),
  tmpfile_directory: Path.join([System.tmp_dir!(), "test", "tmpfiles"]),
  file_watcher_poll_interval: 50

config :pinchflat, Oban, testing: :manual

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :pinchflat, Pinchflat.Repo,
  database: Path.expand("../priv/repo/pinchflat_test.db", Path.dirname(__ENV__.file)),
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pinchflat, PinchflatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "1Mp1Qr5+euvQn3UdcwW6oZn0HGE7f3vgV44dnKJd6t9PIwe7aiVg/L5QN7460biH",
  server: false

# In test we don't send emails.
config :pinchflat, Pinchflat.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

config :logger, level: :critical

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
