defmodule Paianjen.Listings.Listing do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "listings" do
    field :group_id, Ecto.UUID
    field :is_canonical, :boolean, default: false
    field :source_name, :string
    field :title, :string
    field :description, :string
    field :price, :integer
    field :currency, :string, default: "EUR"
    field :price_per_sqm, :float
    field :rooms, :integer
    field :surface_area, :float
    field :usable_area, :float
    field :floor, :integer
    field :total_floors, :integer
    field :seller_type, :string, default: "private"
    field :is_private_seller, :boolean, default: false
    field :is_delisted, :boolean, default: false
    field :district, :string
    field :zone, :string
    field :city, :string
    field :street, :string
    field :latitude, :float
    field :longitude, :float
    field :url, :string
    field :first_seen_at, :utc_datetime
    field :last_scraped_at, :utc_datetime
    field :seller_name, :string
    field :seller_agency, :string
    field :seller_phone, :string
    field :property_type, :string
    field :thumbnail, :string
    field :images, {:array, :string}, default: []
    field :features, :map, default: %{}
    field :agency_commission, :integer, default: 0
    field :balcony_surface, :float
    field :parking_price, :integer
    field :delisted_date, :utc_datetime
    field :price_with_vat, :integer
    field :vat_included, :boolean, default: false
    field :price_history, {:array, :map}, default: []
    field :upserted_at, :utc_datetime
    # search_vector is a PostgreSQL tsvector column managed by DB trigger
    # Not mapped in Ecto schema — populated via SQL trigger in migration

    timestamps(type: :utc_datetime)
  end

  def changeset(listing, attrs) do
    listing
    |> cast(attrs, [
      :id, :group_id, :is_canonical, :source_name, :title, :description,
      :price, :currency, :price_per_sqm, :rooms, :surface_area, :usable_area,
      :floor, :total_floors, :seller_type, :is_private_seller, :is_delisted,
      :district, :zone, :city, :street, :latitude, :longitude, :url,
      :first_seen_at, :last_scraped_at, :seller_name, :seller_agency,
      :seller_phone, :property_type, :thumbnail, :images, :features,
      :agency_commission, :balcony_surface, :parking_price, :delisted_date,
      :price_with_vat, :vat_included, :price_history,
      :upserted_at
    ])
    |> validate_required([:id, :title])
  end
end
