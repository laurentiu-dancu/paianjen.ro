import Config

config :paianjen, PaianjenWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 4000],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  server: true

config :paianjen, Paianjen.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  ssl: false

config :logger, level: :info
