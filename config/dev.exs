import Config

config :paianjen, Paianjen.Repo,
  database: "paianjen_dev",
  username: "paianjen",
  password: "paianjen_dev_secret",
  hostname: "db",
  port: 5432,
  pool_size: 10,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :paianjen, PaianjenWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_bytes_long_for_phoenix_zzz",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:paianjen, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:paianjen, ~w(--watch)]}
  ]

config :paianjen, PaianjenWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/paianjen_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"lib/paianjen_web/templates/.*(eex)$",
      ~r"lib/paianjen_web/views/.*(ex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view, :debug_heex_annotations, true
