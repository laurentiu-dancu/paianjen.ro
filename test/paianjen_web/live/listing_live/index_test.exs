defmodule PaianjenWeb.ListingLive.IndexTest do
  use PaianjenWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Paianjen.Listings
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Repo

  @base_time ~U[2026-07-01 12:00:00Z]

  describe "mount/3" do
    test "mounts from the top with offset 0 when no cursor is given", %{conn: conn} do
      insert_groups!(25)

      {:ok, view, _html} = live(authed_conn(conn), "/listari")

      html = render(view)
      # First page renders the 20 newest groups (g25..g6).
      assert length(card_group_ids(html)) == 20
      assert hd(card_group_ids(html)) == group_id(25)
      assert groups_list_attr(html, "data-page") == "1"
      assert groups_list_has_attr?(html, "data-has-more")
    end

    test "mounts at a non-multiple-of-page_size offset when a cursor is given", %{conn: conn} do
      insert_groups!(50)
      cursor = Repo.get!(ListingGroup, group_id(40))

      # g40 is at position 10 (50 - 40), which is not a multiple of 20,
      # so the cursor group must be the first card after mount.
      {:ok, view, _html} = live(authed_conn(conn), "/listari?cursor=#{cursor.id}")

      html = render(view)
      assert hd(card_group_ids(html)) == cursor.id
      assert length(card_group_ids(html)) == 20
      assert groups_list_attr(html, "data-page") == "1"
      assert groups_list_has_attr?(html, "data-has-more")
    end
  end

  describe "load_more" do
    test "continues from the resolved cursor offset without duplicating groups", %{conn: conn} do
      insert_groups!(50)
      cursor = Repo.get!(ListingGroup, group_id(40))

      {:ok, view, _html} = live(authed_conn(conn), "/listari?cursor=#{cursor.id}")
      assert length(card_group_ids(render(view))) == 20

      view |> element("button[phx-click=load_more]") |> render_click()

      # The fix: the next offset is derived from the actual loaded offset
      # (10 + 20 = 30), not from the page number ((2 - 1) * 20 = 20, which
      # would overlap positions 20..29 already shown after mount).
      html = render(view)
      ids = card_group_ids(html)

      assert length(ids) == 40
      assert length(Enum.uniq(ids)) == length(ids)
      assert groups_list_attr(html, "data-page") == "2"
      assert groups_list_has_attr?(html, "data-has-more")
    end

    test "load_more keeps advancing until the end of the result set", %{conn: conn} do
      insert_groups!(50)
      cursor = Repo.get!(ListingGroup, group_id(40))

      {:ok, view, _html} = live(authed_conn(conn), "/listari?cursor=#{cursor.id}")

      view |> element("button[phx-click=load_more]") |> render_click()

      html = render(view)
      assert length(card_group_ids(html)) == 40
      assert groups_list_attr(html, "data-page") == "2"
      assert groups_list_has_attr?(html, "data-has-more")

      # The cursor window is positions 10..49 (40 groups); a second load_more
      # reaches the end, appending nothing new.
      view |> element("button[phx-click=load_more]") |> render_click()

      html = render(view)
      assert length(card_group_ids(html)) == 40
      assert length(Enum.uniq(card_group_ids(html))) == 40
      assert groups_list_attr(html, "data-page") == "3"
      refute groups_list_has_attr?(html, "data-has-more")
    end
  end

  describe "floor selector" do
    test "clicking a floor button cycles include -> exclude -> neutral without submitting", %{
      conn: conn
    } do
      insert_groups!(1)

      {:ok, view, _html} = live(authed_conn(conn), "/listari")

      parter_btn =
        view |> element("button[phx-click=toggle_floor][phx-value-floor=parter]")

      # 1st click: include (indigo) — still on the same page (no navigation).
      render_click(parter_btn)
      assert render(parter_btn) =~ "bg-indigo-50 border-indigo-300 text-indigo-700"

      # 2nd click: exclude (red).
      render_click(parter_btn)
      assert render(parter_btn) =~ "bg-red-50 border-red-300 text-red-700"

      # 3rd click: back to neutral (grey/white).
      render_click(parter_btn)
      assert render(parter_btn) =~ "bg-white border-slate-200 text-slate-600 hover:border-slate-300"
    end

    test "multiple floor buckets can be included at the same time", %{conn: conn} do
      insert_groups!(1)

      {:ok, view, _html} = live(authed_conn(conn), "/listari")

      view |> element("button[phx-click=toggle_floor][phx-value-floor=parter]") |> render_click()
      view |> element("button[phx-click=toggle_floor][phx-value-floor=final]") |> render_click()

      parter_html = render(view |> element("button[phx-click=toggle_floor][phx-value-floor=parter]"))
      final_html = render(view |> element("button[phx-click=toggle_floor][phx-value-floor=final]"))

      assert parter_html =~ "bg-indigo-50 border-indigo-300 text-indigo-700"
      assert final_html =~ "bg-indigo-50 border-indigo-300 text-indigo-700"
    end

    test "submitting the filter form pushes include/exclude floor buckets in the URL", %{
      conn: conn
    } do
      insert_groups!(1)

      {:ok, view, _html} = live(authed_conn(conn), "/listari")

      view |> element("button[phx-click=toggle_floor][phx-value-floor=parter]") |> render_click()
      view |> element("button[phx-click=toggle_floor][phx-value-floor=final]") |> render_click()
      view |> element("button[phx-click=toggle_floor][phx-value-floor=altul]") |> render_click()
      view |> element("button[phx-click=toggle_floor][phx-value-floor=altul]") |> render_click()

      view |> element("form[phx-submit=apply_filters]") |> render_submit()

      assert_redirect(
        view,
        ~p"/listari?page=1&floor_include%5B%5D=parter&floor_include%5B%5D=final&floor_exclude%5B%5D=altul"
      )
    end

    test "editable fields are ignored by the patcher so toggles don't reset them", %{
      conn: conn
    } do
      insert_groups!(1)

      {:ok, view, _html} = live(authed_conn(conn), "/listari")

      # The user-editable fields (search/city/district/price/sqm) live inside an
      # ignored subtree, so a floor/option toggle re-render can't wipe out
      # uncommitted input.
      fields = view |> element("form[phx-submit=apply_filters] div#filter-panel-fields")
      fields_html = render(fields)
      assert fields_html =~ ~s(phx-update="ignore")
      assert fields_html =~ ~s(name="search")
      assert fields_html =~ ~s(name="min_price")

      # The toggle controls themselves stay OUTSIDE the ignored subtree so their
      # tri-state highlight can still be patched after a click.
      refute fields_html =~ "toggle_floor"
      refute fields_html =~ "toggle_parking"
      refute fields_html =~ "toggle_commission"
    end
  end

  describe "wishlist hearts" do
    test "mounts hearts reflecting the session wishlist", %{conn: conn} do
      wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)
      insert_groups!(5)
      group = Repo.get!(ListingGroup, group_id(1))
      Listings.toggle_wishlist_item(wishlist_id, group.id)

      conn =
        Plug.Test.init_test_session(conn, authenticated: true, wishlist_id: wishlist_id)

      {:ok, _view, html} = live(conn, "/listari")

      # The saved group's card shows a filled heart, the others an outline heart.
      assert html =~ "Șterge din colecție"
      assert html =~ "Adaugă în colecție"
    end

    test "toggle_wishlist writes only to the session's wishlist", %{conn: conn} do
      wishlist_id = Ecto.UUID.generate()
      other_wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)
      Listings.create_wishlist(other_wishlist_id)
      insert_groups!(3)
      group = Repo.get!(ListingGroup, group_id(1))

      conn =
        Plug.Test.init_test_session(conn, authenticated: true, wishlist_id: wishlist_id)

      {:ok, view, _html} = live(conn, "/listari")

      view |> element("button[phx-value-group_id='#{group.id}']") |> render_click()

      assert Listings.wishlist_group_ids(wishlist_id) == [group.id]
      assert Listings.wishlist_group_ids(other_wishlist_id) == []
    end
  end

  # ---- Fixtures ----

  defp authed_conn(conn) do
    Plug.Test.init_test_session(conn, authenticated: true)
  end

  defp group_id(n) do
    "00000000-0000-0000-0000-" <> String.pad_leading(Integer.to_string(n), 12, "0")
  end

  defp time(n), do: DateTime.add(@base_time, n, :second)

  defp insert_groups!(count) do
    for n <- 1..count do
      group =
        Repo.insert!(
          ListingGroup.changeset(%ListingGroup{}, %{
            id: group_id(n),
            has_active_listings: true,
            earliest_first_seen: time(n)
          })
        )

      Repo.insert!(
        Listing.changeset(%Listing{}, %{
          id: Ecto.UUID.generate(),
          group_id: group.id,
          title: "Listing #{group.id}",
          price: 100_000,
          thumbnail: "https://example.com/#{group.id}.jpg"
        })
      )
    end
  end

  # ---- HTML helpers ----

  # All rendered group card ids, in DOM order.
  defp card_group_ids(html) do
    Regex.scan(~r/data-group-id="([^"]+)"/, html, capture: :all_but_first)
    |> List.flatten()
  end

  # The opening tag of the #groups-list div (where data-page / data-has-more live).
  defp groups_list_tag(html) do
    case Regex.run(~r/<div id="groups-list"[^>]*>/, html) do
      [tag] -> tag
      _ -> ""
    end
  end

  # Reads a single data-* attribute value (e.g. data-page="2").
  defp groups_list_attr(html, attr) do
    case Regex.run(~r/#{attr}="([^"]*)"/, groups_list_tag(html)) do
      [_, value] -> value
      _ -> nil
    end
  end

  # Phoenix renders a boolean-true attribute as a bare attribute (e.g.
  # data-has-more="data-has-more") and omits it when false, so we test for
  # presence/absence rather than a value.
  defp groups_list_has_attr?(html, attr) do
    String.contains?(groups_list_tag(html), attr)
  end
end
