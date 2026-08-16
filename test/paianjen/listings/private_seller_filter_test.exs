defmodule Paianjen.Listings.PrivateSellerFilterTest do
  use Paianjen.DataCase, async: true

  alias Paianjen.Listings
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Repo

  @base_time ~U[2026-07-01 12:00:00Z]

  # Options that disable the default active + images filters so the
  # private-seller filter can be tested in isolation.
  @opts [only_active: false, include_without_images: true]

  describe "with_private_seller filter" do
    test "includes a group that has an ACTIVE listing from a private seller" do
      group = insert_group!(1)
      insert_listing!(group, is_private_seller: true, is_delisted: false)

      ids = list_ids(Keyword.merge(@opts, with_private_seller: true))

      assert group.id in ids
    end

    test "excludes a group whose only private-seller listing is delisted" do
      group = insert_group!(1)
      insert_listing!(group, is_private_seller: true, is_delisted: true)

      ids = list_ids(Keyword.merge(@opts, with_private_seller: true))

      refute group.id in ids
    end

    test "excludes a group that only has agency listings" do
      group = insert_group!(1)
      insert_listing!(group, is_private_seller: false, is_delisted: false)

      ids = list_ids(Keyword.merge(@opts, with_private_seller: true))

      refute group.id in ids
    end

    test "is a no-op when the filter is off (delisted private listing still shows)" do
      group = insert_group!(1)
      insert_listing!(group, is_private_seller: true, is_delisted: true)

      ids = list_ids(@opts)

      assert group.id in ids
    end

    test "group with a mix of active agency + delisted private seller is excluded" do
      group = insert_group!(1)
      insert_listing!(group, is_private_seller: false, is_delisted: false)
      insert_listing!(group, is_private_seller: true, is_delisted: true)

      ids = list_ids(Keyword.merge(@opts, with_private_seller: true))

      refute group.id in ids
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
