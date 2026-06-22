defmodule PaianjenWeb.LoginController do
  use PaianjenWeb, :controller

  @password "prietenpaianjen"

  def create(conn, %{"password" => password, "return_to" => return_to}) do
    if password == @password do
      conn
      |> put_session(:authenticated, true)
      |> configure_session(renew: true)
      |> redirect(to: return_to || "/listari")
    else
      conn
      |> put_flash(:error, "Parolă incorectă")
      |> redirect(to: "/")
    end
  end

  def create(conn, %{"password" => password}) do
    create(conn, %{"password" => password, "return_to" => "/listari"})
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
