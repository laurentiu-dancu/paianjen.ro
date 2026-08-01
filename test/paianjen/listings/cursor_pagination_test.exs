defmodule Paianjen.Listings.CursorPaginationTest do
  use Paianjen.DataCase, async: true

  alias Paianjen.Listings
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Repo

  @base_time ~U[2026-07-01 12:00:00Z]

  describe "resolve_cursor/2" do
    test "returns {0, 1} when the cursor group does not exist" do
      assert Listings.resolve_cursor(Ecto.UUID.generate()) == {0, 1}
    end

    test "counts the groups that sort before the cursor under the default sort" do
      # g(n) has earliest_first_seen = base + n seconds, so higher n is newer.
      # Under (earliest_first_seen DESC, id ASC): g5 is first, g1 is last.
      for n <- 1..5 do
        group_with_thumbnail!(n)
      end

      # Newest group has nothing before it
      assert Listings.resolve_cursor(group_id(5)) == {0, 1}
      # g4, g5 sort before g3
      assert Listings.resolve_cursor(group_id(3)) == {2, 1}
      # g2..g5 sort before g1
      assert Listings.resolve_cursor(group_id(1)) == {4, 1}
    end

    test "breaks ties on equal earliest_first_seen by id ascending (lower id first)" do
      # Same earliest_first_seen, different ids -> id ASC decides.
      group_with_thumbnail!(1, earliest_first_seen: time(10))
      group_with_thumbnail!(2, earliest_first_seen: time(10))

      # g1 (lower id) sorts before g2, so g2 has exactly 1 group before it.
      assert Listings.resolve_cursor(group_id(2)) == {1, 1}
      # g1 has nothing before it.
      assert Listings.resolve_cursor(group_id(1)) == {0, 1}
    end

    test "applies the active and images filters when counting the position" do
      # g1: active with thumbnail (newest)
      group_with_thumbnail!(1, earliest_first_seen: time(3))
      # g2: active but has NO listing -> excluded by the images filter
      insert_group!(2, earliest_first_seen: time(2))
      # g3: has a thumbnail listing but is inactive -> excluded by the active filter
      group_with_thumbnail!(3, earliest_first_seen: time(1), has_active_listings: false)

      # Only g1 (active + thumbnail) sorts before g3.
      assert Listings.resolve_cursor(group_id(3)) == {1, 1}
    end

    test "last_price_drop sort: NULL-drop cursor counts real drops plus tiebroken NULLs" do
      # All groups share the same earliest_first_seen so the tiebreaker is pure id.
      group_with_thumbnail!(1, earliest_first_seen: time(100), last_price_drop_at: nil)
      group_with_thumbnail!(2, earliest_first_seen: time(100), last_price_drop_at: drop_time(3))
      group_with_thumbnail!(3, earliest_first_seen: time(100), last_price_drop_at: drop_time(2))
      # Cursor: a NULL-drop group (sorts last under NULLS LAST)
      group_with_thumbnail!(4, earliest_first_seen: time(100), last_price_drop_at: nil)

      # Groups before g4: g2, g3 (real drops) + g1 (NULL, id 1 < 4 tiebreak) = 3.
      assert Listings.resolve_cursor(group_id(4), sort_by: "last_price_drop") == {3, 1}
      # A real-drop cursor: only g2's drop (drop_time(3)) is newer than g3's.
      assert Listings.resolve_cursor(group_id(3), sort_by: "last_price_drop") == {1, 1}
      # Newest drop sorts first.
      assert Listings.resolve_cursor(group_id(2), sort_by: "last_price_drop") == {0, 1}
    end

    test "last_price_drop sort: filters still apply to BOTH branches of the OR" do
      # Regression test for the old `where |> or_where(...)` bug, which produced
      # `(filters AND A) OR B` and let the B branch escape the active/images filters.
      #
      # Sort order under last_price_drop DESC NULLS LAST, then id ASC:
      #   g5 (drop5, no image), g4 (drop4, inactive), g2 (drop3), g3 (drop2), g1 (NULL)
      # All share earliest_first_seen so ties resolve by id.
      group_with_thumbnail!(1, earliest_first_seen: time(100), last_price_drop_at: nil)
      group_with_thumbnail!(2, earliest_first_seen: time(100), last_price_drop_at: drop_time(3))
      group_with_thumbnail!(3, earliest_first_seen: time(100), last_price_drop_at: drop_time(2))
      # Cursor: NULL-drop group, id 4
      group_with_thumbnail!(4, earliest_first_seen: time(100), last_price_drop_at: nil)
      # g4 has a thumbnail listing but is INACTIVE -> must not be counted
      group_with_thumbnail!(5, earliest_first_seen: time(100), last_price_drop_at: drop_time(4),
        has_active_listings: false
      )
      # g5 is active but has NO listing -> must not be counted (images filter)
      insert_group!(6, earliest_first_seen: time(100), last_price_drop_at: drop_time(5))

      # With the fix only active groups with a thumbnail are counted:
      # g2, g3 (real drops) + g1 (NULL tiebreak) = 3.
      # The old or_where bug would also count g4 (inactive) and g5 (no image) -> 5.
      assert Listings.resolve_cursor(group_id(4), sort_by: "last_price_drop") == {3, 1}
    end
  end

  describe "list_groups_before_cursor/2" do
    test "returns {[], false} when the cursor group does not exist" do
      assert Listings.list_groups_before_cursor(Ecto.UUID.generate()) == {[], false}
    end

    test "returns newer groups newest-first and flags has_more beyond the page size" do
      for n <- 1..25 do
        group_with_thumbnail!(n)
      end

      # Cursor g4: 21 groups sort before it (g5..g25), so we expect 20 returned + has_more.
      {groups, has_more} = Listings.list_groups_before_cursor(group_id(4), page_size: 20)

      assert has_more == true
      assert length(groups) == 20
      assert hd(groups).id == group_id(25)
      assert List.last(groups).id == group_id(6)
    end

    test "applies the active filter to the newer groups" do
      group_with_thumbnail!(1, earliest_first_seen: time(3))
      group_with_thumbnail!(2, earliest_first_seen: time(2), has_active_listings: false)
      group_with_thumbnail!(3, earliest_first_seen: time(1))

      {groups, has_more} = Listings.list_groups_before_cursor(group_id(3))

      assert has_more == false
      assert Enum.map(groups, & &1.id) == [group_id(1)]
    end
  end

  describe "list_groups_paginated/1" do
    test "paginates newest-first and reports has_more" do
      for n <- 1..25 do
        group_with_thumbnail!(n)
      end

      page1 = Listings.list_groups_paginated(page: 1, page_size: 20)
      assert page1.total_count == 25
      assert page1.has_more == true
      assert page1.total_pages == 2
      assert length(page1.groups) == 20
      assert hd(page1.groups).id == group_id(25)

      page2 = Listings.list_groups_paginated(page: 2, page_size: 20)
      assert page2.has_more == false
      assert length(page2.groups) == 5
      assert List.last(page2.groups).id == group_id(1)
    end

    test "respects an explicit offset" do
      for n <- 1..25 do
        group_with_thumbnail!(n)
      end

      # Offset 5 skips g25..g21, so the first returned group is g20.
      result = Listings.list_groups_paginated(page: 1, page_size: 20, offset: 5)
      assert length(result.groups) == 20
      assert hd(result.groups).id == group_id(20)
    end

    test "the offset from resolve_cursor places the cursor group first" do
      for n <- 1..25 do
        group_with_thumbnail!(n)
      end

      {offset, _page} = Listings.resolve_cursor(group_id(9))
      assert offset == 16

      result = Listings.list_groups_paginated(page: 1, page_size: 20, offset: offset)
      assert hd(result.groups).id == group_id(9)
    end
  end

  # ---- Fixtures ----

  # Deterministic UUIDs that sort in id order: id(n) < id(n+1).
  defp group_id(n) do
    "00000000-0000-0000-0000-" <> String.pad_leading(Integer.to_string(n), 12, "0")
  end

  defp time(n), do: DateTime.add(@base_time, n, :second)
  defp drop_time(n), do: DateTime.add(@base_time, n * 1000, :second)

  defp insert_group!(n, attrs) do
    attrs =
      Map.merge(
        %{
          id: group_id(n),
          has_active_listings: true,
          earliest_first_seen: time(n)
        },
        Map.new(attrs)
      )

    Repo.insert!(ListingGroup.changeset(%ListingGroup{}, attrs))
  end

  defp insert_listing!(group, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          id: Ecto.UUID.generate(),
          group_id: group.id,
          title: "Listing #{group.id}",
          price: 100_000,
          thumbnail: "https://example.com/#{group.id}.jpg"
        },
        Map.new(attrs)
      )

    Repo.insert!(Listing.changeset(%Listing{}, attrs))
  end

  # Creates an active group plus one listing with a thumbnail so it passes
  # the default active + images filters.
  defp group_with_thumbnail!(n, attrs \\ %{}) do
    group = insert_group!(n, attrs)
    insert_listing!(group)
    group
  end
end
