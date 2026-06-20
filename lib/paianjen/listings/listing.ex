defmodule Paianjen.Listings.Listing do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "listings" do
    field :title, :string
    field :description, :string
    field :price, :integer
    field :currency, :string, default: "EUR"
    field :rooms, :integer
    field :surface, :float
    field :floor, :integer
    field :seller_type, :string, default: "private"
    field :district, :string
    field :neighborhood, :string
    field :original_url, :string
    field :first_discovered, :utc_datetime
    field :last_seen, :utc_datetime
    field :is_active, :boolean, default: true
    field :images, {:array, :string}, default: []
    field :features, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(listing, attrs) do
    listing
    |> cast(attrs, [
      :title, :description, :price, :currency, :rooms, :surface, :floor,
      :seller_type, :district, :neighborhood, :original_url,
      :first_discovered, :last_seen, :is_active, :images, :features
    ])
    |> validate_required([:title, :price, :seller_type])
    |> validate_inclusion(:seller_type, ["private", "agency"])
    |> validate_number(:price, greater_than: 0)
  end
end
