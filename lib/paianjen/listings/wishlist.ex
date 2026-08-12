defmodule Paianjen.Listings.Wishlist do
  @moduledoc """
  A wishlist ("colecție") — a server-side list of saved listing groups.

  The row is keyed by a bearer uuid that lives in the session (not in the
  cookie payload), so the cookie stays tiny and the uuid can never be forged
  by the client. Anyone with the uuid + the public password can VIEW the list;
  only the session that owns it can EDIT it.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Paianjen.Listings.WishlistItem

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "wishlists" do
    has_many :items, WishlistItem, foreign_key: :wishlist_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(wishlist, attrs \\ %{}) do
    wishlist
    |> cast(attrs, [:id])
    |> validate_required([:id])
  end
end
