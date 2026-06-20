defmodule Paianjen.Repo do
  use Ecto.Repo,
    otp_app: :paianjen,
    adapter: Ecto.Adapters.Postgres
end
