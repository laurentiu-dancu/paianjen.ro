import Config

# Test DB. Defaults target the docker-compose `db` service (see docker-compose.yml),
# matching how the rest of the project is developed/run in Docker.
# Override via TEST_DATABASE / TEST_DB_USERNAME / TEST_DB_PASSWORD / TEST_DB_HOST
# when running the suite against a different Postgres instance.
config :paianjen, Paianjen.Repo,
  database: System.get_env("TEST_DATABASE", "paianjen_test"),
  username: System.get_env("TEST_DB_USERNAME", "paianjen"),
  password: System.get_env("TEST_DB_PASSWORD", "paianjen_dev_secret"),
  hostname: System.get_env("TEST_DB_HOST", "db"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :paianjen, PaianjenWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_phoenix_testing",
  server: false

config :paianjen, Paianjen.Mailer, adapter: Swoosh.Adapters.Test

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime
