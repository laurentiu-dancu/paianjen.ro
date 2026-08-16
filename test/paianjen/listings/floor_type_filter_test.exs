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
    test "parter matches a group with a ground-floor (floor == 0) listing" do
      group = insert_group!(1)
      insert_listing!(group, floor: 0, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "parter"))
    end

    test "intermediar matches a group with a floor strictly between 0 and total_floors" do
      group = insert_group!(1)
      insert_listing!(group, floor: 2, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "intermediar"))
    end

    test "final matches a group with floor == total_floors (top floor)" do
      group = insert_group!(1)
      insert_listing!(group, floor: 5, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "final"))
    end

    test "final matches a group with floor greater than total_floors" do
      group = insert_group!(1)
      insert_listing!(group, floor: 6, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "final"))
    end

    test "altul matches a group with floor == -1 (unknown floor)" do
      group = insert_group!(1)
      insert_listing!(group, floor: -1, total_floors: 5)

      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "altul"))
    end

    test "altul matches a group whose listing has unknown total_floors" do
      group = insert_group!(1)
      insert_listing!(group, floor: 2, total_floors: nil)

      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "altul"))
    end

    test "categories are mutually exclusive: a top-floor group is not intermediar" do
      group = insert_group!(1)
      insert_listing!(group, floor: 5, total_floors: 5)

      refute group.id in list_ids(Keyword.merge(@opts, floor_type: "intermediar"))
      assert group.id in list_ids(Keyword.merge(@opts, floor_type: "final"))
    end

    test "is a no-op when floor_type is unset" do
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
