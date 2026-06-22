defmodule PaianjenWeb.AuthPlug do
  @moduledoc """
  Plug that requires authentication via session.

  If the session does not contain `authenticated: true`, the user is
  redirected to the landing page (`/`).
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :authenticated) do
      true ->
        conn

      _ ->
        conn
        |> put_flash(:error, "")
        |> redirect(to: "/")
        |> halt()
    end
  end
end
