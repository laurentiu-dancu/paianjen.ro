defmodule Paianjen.Listings.WishlistTest do
  use Paianjen.DataCase, async: true

  alias Paianjen.Listings
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Repo

  describe "create_wishlist/1" do
    test "is idempotent" do
      id = Ecto.UUID.generate()

      assert {:ok, _} = Listings.create_wishlist(id)
      assert {:ok, _} = Listings.create_wishlist(id)
      assert Listings.wishlist_exists?(id)
    end

    test "generates its own id when none is given" do
      assert {:ok, wishlist} = Listings.create_wishlist()
      assert wishlist.id
      assert Listings.wishlist_exists?(wishlist.id)
    end
  end

  describe "toggle_wishlist_item/2" do
    test "adds then removes a group idempotently" do
      wishlist_id = Ecto.UUID.generate()
      group_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)

      assert {:ok, :added} = Listings.toggle_wishlist_item(wishlist_id, group_id)
      assert Listings.wishlist_group_ids(wishlist_id) == [group_id]

      # Adding the same group again is a no-op toggle back to remove.
      assert {:ok, :removed} = Listings.toggle_wishlist_item(wishlist_id, group_id)
      assert Listings.wishlist_group_ids(wishlist_id) == []
    end

    test "is isolated per wishlist" do
      w1 = Ecto.UUID.generate()
      w2 = Ecto.UUID.generate()
      group_id = Ecto.UUID.generate()

      Listings.create_wishlist(w1)
      Listings.create_wishlist(w2)

      assert {:ok, :added} = Listings.toggle_wishlist_item(w1, group_id)
      assert Listings.wishlist_group_ids(w1) == [group_id]
      assert Listings.wishlist_group_ids(w2) == []
    end

    test "returns {:error, :not_found} for a missing wishlist" do
      assert {:error, :not_found} =
               Listings.toggle_wishlist_item(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "rejects additions past the size cap" do
      wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)

      for _n <- 1..200 do
        assert {:ok, :added} =
                 Listings.toggle_wishlist_item(wishlist_id, Ecto.UUID.generate())
      end

      assert {:error, :wishlist_full} =
               Listings.toggle_wishlist_item(wishlist_id, Ecto.UUID.generate())

      # Toggling an existing item still removes it at the cap.
      [existing | _] = Listings.wishlist_group_ids(wishlist_id)
      assert {:ok, :removed} = Listings.toggle_wishlist_item(wishlist_id, existing)
    end
  end

  describe "list_wishlist_entries/1" do
    test "returns saved groups newest-first and skips deleted groups" do
      wishlist_id = Ecto.UUID.generate()
      Listings.create_wishlist(wishlist_id)

      group_a = insert_group!()
      group_b = insert_group!()
      Listings.toggle_wishlist_item(wishlist_id, group_a.id)
      Listings.toggle_wishlist_item(wishlist_id, group_b.id)

      # group_a disappears (e.g. import cleanup_orphans) — the inner join must
      # skip it instead of crashing.
      Repo.delete!(group_a)

      entries = Listings.list_wishlist_entries(wishlist_id)
      assert Enum.map(entries, & &1.group.id) == [group_b.id]
    end
  end

  defp insert_group! do
    Repo.insert!(%ListingGroup{
      id: Ecto.UUID.generate(),
      has_active_listings: true,
      earliest_first_seen: ~U[2026-07-01 12:00:00Z]
    })
  end
end
