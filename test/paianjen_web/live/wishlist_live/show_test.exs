defmodule PaianjenWeb.WishlistLive.ShowTest do
  use PaianjenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Paianjen.Listings
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Repo

  describe "mount/3" do
    test "owner sees their own collection without share controls", %{conn: conn} do
      wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)
      group = insert_group!()
      Listings.toggle_wishlist_item(wishlist_id, group.id)

      {:ok, _view, html} = live(authed_conn(conn, wishlist_id), "/colectii/#{wishlist_id}")

      assert html =~ "Colecția mea"
      assert html =~ group.id

      # The owner's own page has no share link and no sharing hint.
      refute html =~ "Link de partajare"
      refute html =~ "/colectii/#{wishlist_id}"
      refute html =~ "Partajează"
    end

    test "a non-owner can view a shared collection", %{conn: conn} do
      owner_id = Ecto.UUID.generate()
      viewer_id = Ecto.UUID.generate()
      Listings.create_wishlist(owner_id)
      Listings.create_wishlist(viewer_id)
      group = insert_group!()
      Listings.toggle_wishlist_item(owner_id, group.id)

      {:ok, _view, html} = live(authed_conn(conn, viewer_id), "/colectii/#{owner_id}")

      assert html =~ "Colecție partajată"
      refute html =~ "Link de partajare"
      assert html =~ group.id
    end

    test "a missing wishlist renders a friendly not-found", %{conn: conn} do
      wishlist_id = Ecto.UUID.generate()

      {:ok, _view, html} = live(authed_conn(conn, wishlist_id), "/colectii/#{wishlist_id}")

      assert html =~ "Colecția nu a fost găsită"
    end

    test "deleted groups are skipped gracefully (no crash)", %{conn: conn} do
      wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)
      group = insert_group!()
      Listings.toggle_wishlist_item(wishlist_id, group.id)
      Repo.delete!(group)

      {:ok, _view, html} = live(authed_conn(conn, wishlist_id), "/colectii/#{wishlist_id}")

      assert html =~ "Colecția e goală"
    end

    test "unauthenticated users are redirected to /", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> get("/colectii/#{Ecto.UUID.generate()}")

      assert redirected_to(conn) == "/"
    end
  end

  describe "toggle_wishlist/2" do
    test "writes to the viewer's own wishlist, not the shared one", %{conn: conn} do
      owner_id = Ecto.UUID.generate()
      viewer_id = Ecto.UUID.generate()
      Listings.create_wishlist(owner_id)
      Listings.create_wishlist(viewer_id)
      group = insert_group!()

      # Owner saved the group; the viewer hasn't.
      Listings.toggle_wishlist_item(owner_id, group.id)

      {:ok, view, _html} = live(authed_conn(conn, viewer_id), "/colectii/#{owner_id}")

      # Viewer toggles their own heart → group is now in THEIR wishlist.
      view |> element("button[phx-value-group_id='#{group.id}']") |> render_click()

      assert Listings.wishlist_group_ids(viewer_id) == [group.id]
      # The owner's collection is untouched.
      assert Listings.wishlist_group_ids(owner_id) == [group.id]
    end
  end

  defp authed_conn(conn, wishlist_id) do
    Plug.Test.init_test_session(conn, authenticated: true, wishlist_id: wishlist_id)
  end

  defp insert_group! do
    Repo.insert!(%ListingGroup{
      id: Ecto.UUID.generate(),
      has_active_listings: true,
      earliest_first_seen: ~U[2026-07-01 12:00:00Z]
    })
  end
end
