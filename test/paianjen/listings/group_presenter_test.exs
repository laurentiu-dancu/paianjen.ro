defmodule Paianjen.Listings.GroupPresenterTest do
  use ExUnit.Case, async: true

  alias Paianjen.Listings.GroupPresenter
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup

  defp group(attrs \\ %{}) do
    struct!(ListingGroup, Map.merge(%{id: "g1", has_active_listings: true}, attrs))
  end

  defp listing(id, attrs) do
    struct!(Listing, Map.merge(%{id: id, group_id: "g1", price: 100_000}, attrs))
  end

  describe "floor and total_floors" do
    test "uses the canonical listing's floor and total_floors when present" do
      listings = [
        listing("l1", %{is_canonical: true, floor: 4, total_floors: 10}),
        listing("l2", %{is_canonical: false, floor: 4, total_floors: 10})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.floor == 4
      assert presenter.total_floors == 10
    end

    test "infers total_floors from sibling listings when the canonical lacks it" do
      listings = [
        listing("l1", %{is_canonical: true, floor: 4, total_floors: nil}),
        listing("l2", %{is_canonical: false, floor: 4, total_floors: 4}),
        listing("l3", %{is_canonical: false, floor: 4, total_floors: 4})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.floor == 4
      assert presenter.total_floors == 4
    end

    test "infers floor too when the canonical lacks it" do
      listings = [
        listing("l1", %{is_canonical: true, floor: nil, total_floors: nil}),
        listing("l2", %{is_canonical: false, floor: 2, total_floors: 8}),
        listing("l3", %{is_canonical: false, floor: 2, total_floors: 8})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.floor == 2
      assert presenter.total_floors == 8
    end

    test "considers inactive (delisted) listings in the fallback" do
      listings = [
        listing("l1", %{is_canonical: true, floor: 4, total_floors: nil}),
        listing("l2", %{is_canonical: false, is_delisted: true, floor: 4, total_floors: 4})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.total_floors == 4
    end

    test "majority value wins when listings disagree" do
      listings = [
        listing("l1", %{is_canonical: true, floor: nil, total_floors: nil}),
        listing("l2", %{is_canonical: false, floor: nil, total_floors: 4}),
        listing("l3", %{is_canonical: false, floor: nil, total_floors: 4}),
        listing("l4", %{is_canonical: false, floor: nil, total_floors: 5})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.total_floors == 4
    end

    test "minimum value wins on a tie" do
      listings = [
        listing("l1", %{is_canonical: true, floor: nil, total_floors: nil}),
        listing("l2", %{is_canonical: false, floor: nil, total_floors: 4}),
        listing("l3", %{is_canonical: false, floor: nil, total_floors: 5})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.total_floors == 4
    end

    test "returns nil when no listing provides a value" do
      listings = [
        listing("l1", %{is_canonical: true, floor: nil, total_floors: nil}),
        listing("l2", %{is_canonical: false, floor: nil, total_floors: nil})
      ]

      presenter = GroupPresenter.from_group(group(), listings)

      assert presenter.floor == nil
      assert presenter.total_floors == nil
    end
  end
end
