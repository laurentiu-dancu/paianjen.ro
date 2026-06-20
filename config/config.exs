import Config

config :paianjen,
  ecto_repos: [Paianjen.Repo],
  generators: [timestamp_type: :utc_datetime]

config :paianjen, Paianjen.Repo,
  database: "paianjen_dev",
  username: "paianjen",
  password: "paianjen_dev_secret",
  hostname: "db",
  pool_size: 10,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :paianjen, PaianjenWeb.Gettext,
  default_locale: "ro",
  locales: ~w(en ro)

config :paianjen, PaianjenWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PaianjenWeb.ErrorHTML, json: PaianjenWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Paianjen.PubSub,
  live_view: [signing_salt: "dev_salt_change_in_prod"]

config :esbuild,
  version: "0.17.11",
  paianjen: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  paianjen: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
