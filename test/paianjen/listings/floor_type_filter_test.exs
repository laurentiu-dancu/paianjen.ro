defmodule Paianjen.Listings.FloorTypeFilterTest do
  use Paianjen.DataCase, async: true

  alias Paianjen.Listings
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Repo

  @base_time ~U[2026-07-01 12:00:00Z]

  # Options that disable the default active + images filters so the floor-type
  # filter can be tested in isolation.
  @opts [only_active: false, include_without_images: true]

  describe "floor_type filter" do
    # ---- Positive (include): at least one listing in any included bucket ----

    test "parter matches a group with a ground-floor (floor == 0) listing" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["parter"]))
    end

    test "intermediar matches a group with a floor strictly between 0 and total_floors" do
      group = insert_group!(1)
      insert_listing!(group, floor: 2, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["intermediar"]))
    end

    test "final matches a group with floor == total_floors (top floor)" do
      group = insert_group!(1)
      insert_listing!(group, floor: 5, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["final"]))
    end

    test "final matches a group with floor greater than total_floors" do
      group = insert_group!(1)
      insert_listing!(group, floor: 6, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["final"]))
    end

    test "altul matches a group with floor == -1 (unknown floor)" do
      group = insert_group!(1)
      insert_listing!(group, floor: -1, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["altul"]))
    end

    test "altul matches a group whose listing has unknown total_floors" do
      group = insert_group!(1)
      insert_listing!(group, floor: 2, total_floors: nil)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["altul"]))
    end

    test "categories are mutually exclusive: a top-floor group is not intermediar" do
      group = insert_group!(1)
      insert_listing!(group, floor: 5, total_floors: 5)

      refute group.id in list_ids(Keyword.merge(@opts, floor_include: ["intermediar"]))
      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["final"]))
    end

    test "a degenerates floor 0 / total 0 listing counts as parter only" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 0)

      assert group.id in list_ids(Keyword.merge(@opts, floor_include: ["parter"]))
      refute group.id in list_ids(Keyword.merge(@opts, floor_include: ["final"]))
      refute group.id in list_ids(Keyword.merge(@opts, floor_include: ["altul"]))
    end

    test "multiple includes are inclusive (OR): any included bucket matches" do
      parter_group = insert_group!(1)
      insert_listing!(parter_group, floor: 0, total_floors: 5)

      final_group = insert_group!(2)
      insert_listing!(final_group, floor: 5, total_floors: 5)

      inter_group = insert_group!(3)
      insert_listing!(inter_group, floor: 2, total_floors: 5)

      ids = list_ids(Keyword.merge(@opts, floor_include: ["parter", "final"]))

      assert parter_group.id in ids
      assert final_group.id in ids
      refute inter_group.id in ids
    end

    # ---- Negative (exclude): hide groups that are >= half one excluded bucket ----

    test "exclude hides a group whose only listing is in that bucket" do
      parter_group = insert_group!(1)
      insert_listing!(parter_group, floor: 0, total_floors: 5)

      final_group = insert_group!(2)
      insert_listing!(final_group, floor: 5, total_floors: 5)

      ids = list_ids(Keyword.merge(@opts, floor_exclude: ["parter"]))

      refute parter_group.id in ids
      assert final_group.id in ids
    end

    test "exclude hides a group that is exactly half in that bucket (1 of 2)" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5)
      insert_listing!(group, floor: 5, total_floors: 5)

      refute group.id in list_ids(Keyword.merge(@opts, floor_exclude: ["parter"]))
      refute group.id in list_ids(Keyword.merge(@opts, floor_exclude: ["final"]))
    end

    test "exclude keeps a group that is only a minority in that bucket" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5)
      insert_listing!(group, floor: 5, total_floors: 5)
      insert_listing!(group, floor: 5, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_exclude: ["parter"]))
    end

    test "exclude counts delisted listings too (data is data)" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5, is_delisted: false)
      insert_listing!(group, floor: 0, total_floors: 5, is_delisted: true)
      insert_listing!(group, floor: 5, total_floors: 5, is_delisted: true)

      # 2/3 listings are parter (including a delisted one) -> excluded.
      refute group.id in list_ids(Keyword.merge(@opts, floor_exclude: ["parter"]))
    end

    test "multiple excludes hide if any excluded bucket is at least half" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5)
      insert_listing!(group, floor: 0, total_floors: 5)

      ids = list_ids(Keyword.merge(@opts, floor_exclude: ["parter", "final"]))

      refute group.id in ids
    end

    # ---- Mixed: positives win, negatives ignored ----

    test "when includes are set, excludes are ignored (positives win)" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5)
      insert_listing!(group, floor: 5, total_floors: 5)
      insert_listing!(group, floor: 5, total_floors: 5)

      # 2/3 final would be excluded by ¬final alone, but the parter include wins.
      ids = Listings.list_groups(Keyword.merge(@opts, floor_include: ["parter"], floor_exclude: ["final"])) |> Enum.map(& &1.id)

      assert group.id in ids
    end

    test "is a no-op when no floor buckets are selected" do
      group = insert_group!(1)
      insert_listing!(group, floor: 2, total_floors: 5)

      assert group.id in list_ids(@opts)
    end
  end

  # ---- Fixtures ----

  defp list_ids(opts), do: Listings.list_groups(opts) |> Enum.map(& &1.id)

  defp group_id(n) do
    "00000000-0000-0000-0000-" <> String.pad_leading(Integer.to_string(n), 12, "0")
  end

  defp time(n), do: DateTime.add(@base_time, n, :second)

  defp insert_group!(n, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{id: group_id(n), has_active_listings: true, earliest_first_seen: time(n)},
        Map.new(attrs)
      )

    Repo.insert!(ListingGroup.changeset(%ListingGroup{}, attrs))
  end

  defp insert_listing!(group, attrs) do
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
end
