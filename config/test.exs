import Config

config :pinchflat,
  # Specifying backend data here makes mocking and local testing SUPER easy
  yt_dlp_executable: Path.join([File.cwd!(), "/test/support/scripts/yt-dlp-mocks/repeater.sh"]),
  media_directory: Path.join([System.tmp_dir!(), "yt-dlp"])

config :pinchflat, Oban, testing: :inline

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :pinchflat, Pinchflat.Repo,
  username: System.get_env("POSTGRES_USER"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: System.get_env("POSTGRES_HOST"),
  database: "pinchflat_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

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

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
