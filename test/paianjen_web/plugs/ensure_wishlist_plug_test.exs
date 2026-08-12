defmodule PaianjenWeb.EnsureWishlistPlugTest do
  use PaianjenWeb.ConnCase, async: false

  alias Paianjen.Listings

  describe "call/2" do
    test "assigns a wishlist_id when the session has none", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> PaianjenWeb.EnsureWishlistPlug.call([])

      wishlist_id = get_session(conn, :wishlist_id)
      assert wishlist_id
      assert Listings.wishlist_exists?(wishlist_id)
    end

    test "keeps an existing wishlist_id untouched", %{conn: conn} do
      wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)

      conn =
        conn
        |> Plug.Test.init_test_session(wishlist_id: wishlist_id)
        |> PaianjenWeb.EnsureWishlistPlug.call([])

      assert get_session(conn, :wishlist_id) == wishlist_id
    end
  end

  describe "through the :authenticated pipeline" do
    test "unauthenticated requests are redirected to /", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> get("/listari")

      assert redirected_to(conn) == "/"
    end

    test "authenticated requests without a token receive one", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(authenticated: true)
        |> get("/listari")

      assert response(conn, 200)
      assert get_session(conn, :wishlist_id)
    end
  end
end
