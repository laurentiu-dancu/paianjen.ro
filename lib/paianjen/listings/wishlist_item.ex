defmodule Paianjen.Listings.WishlistItem do
  @moduledoc """
  A saved listing group inside a wishlist.

  Composite primary key `(wishlist_id, group_id)` makes the toggle idempotent.
  `group_id` has no foreign key to `listing_groups` on purpose — see the
  migration for the reasoning. `added_at` provides the ordering (newest first).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "wishlist_items" do
    field :wishlist_id, :binary_id, primary_key: true
    field :group_id, :binary_id, primary_key: true
    field :added_at, :utc_datetime
  end

  @doc false
  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:wishlist_id, :group_id, :added_at])
    |> validate_required([:wishlist_id, :group_id])
  end
end
