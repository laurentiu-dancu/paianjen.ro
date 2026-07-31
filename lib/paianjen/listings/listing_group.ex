defmodule Paianjen.Listings.ListingGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Paianjen.Listings.Listing

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "listing_groups" do
    field :algorithm_version, :string
    field :listing_count, :integer, default: 0
    field :min_price, :float
    field :max_price, :float
    field :min_surface, :float
    field :max_surface, :float
    field :min_price_per_sqm, :float
    field :max_price_per_sqm, :float
    field :earliest_first_seen, :utc_datetime
    field :has_top_floor, :boolean, default: false
    field :has_private_seller, :boolean, default: false
    field :has_active_listings, :boolean, default: false
    field :group_thumbnail, :string
    field :group_district, :string
    field :group_city, :string
    field :group_zone, :string
    field :refreshed_at, :utc_datetime
    field :price_history, {:array, :map}, default: []
    field :last_price_drop_at, :utc_datetime
    field :upserted_at, :utc_datetime

    has_many :listings, Listing, foreign_key: :group_id

    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :id, :algorithm_version, :listing_count, :min_price, :max_price,
      :min_surface, :max_surface, :min_price_per_sqm, :max_price_per_sqm,
      :earliest_first_seen, :has_top_floor, :has_private_seller, :has_active_listings,
      :group_thumbnail, :group_district, :group_city, :group_zone, :refreshed_at,
      :price_history, :last_price_drop_at,
      :upserted_at
    ])
    |> validate_required([:id])
  end
end
