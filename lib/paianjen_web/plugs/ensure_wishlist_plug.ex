defmodule PaianjenWeb.EnsureWishlistPlug do
  @moduledoc """
  Ensures every authenticated session carries a `wishlist_id`.

  The id is a bearer key pointing at a server-side `wishlists` row — the
  session cookie only ever holds `authenticated` + this one uuid. Because the
  cookie is signed, the client can read but never forge the value, which is
  what makes "read-only for everyone but the creator" enforceable.

  Self-healing: if the session has no `wishlist_id`, generate one, persist the
  row, and store it in the session. Runs after `AuthPlug` inside the
  `:authenticated` pipeline, so existing users are never logged out — they
  simply receive a wishlist on their next page load.
  """
  import Plug.Conn
  alias Paianjen.Listings

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :wishlist_id) do
      nil ->
        wishlist_id = Ecto.UUID.generate()
        Listings.create_wishlist(wishlist_id)
        put_session(conn, :wishlist_id, wishlist_id)

      _existing ->
        conn
    end
  end
end
