import Config

read_secret = fn path ->
  case File.read(path) do
    {:ok, contents} -> String.trim(contents)
    _ -> nil
  end
end

db_user = System.get_env("POSTGRES_USER") || "postgres"
db_password_file = System.get_env("POSTGRES_PASSWORD_FILE")

db_password =
  System.get_env("POSTGRES_PASSWORD") ||
    if(db_password_file, do: read_secret.(db_password_file), else: nil) ||
    "postgres"

db_host = System.get_env("POSTGRES_HOST") || "localhost"
db_name = "luca_webapp_test#{System.get_env("MIX_TEST_PARTITION")}"

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :luca_webapp, LucaWebapp.Repo,
  username: db_user,
  password: db_password,
  hostname: db_host,
  database: db_name,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :luca_webapp, LucaWebappWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DuFcfJegWiMT/vFIqQKjhEKjqTlLaV+s3P4XCWbVEifT0Zy+Cb+QMjR8xdggOUM0",
  server: false

# In test we don't send emails
config :luca_webapp, LucaWebapp.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :luca_webapp, booking_cleanup_enabled: false
