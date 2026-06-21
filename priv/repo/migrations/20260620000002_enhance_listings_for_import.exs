defmodule Paianjen.Repo.Migrations.EnhanceListingsForImport do
  use Ecto.Migration

  def change do
    # Rename existing columns to match new naming convention
    rename table(:listings), :surface, to: :surface_area
    rename table(:listings), :neighborhood, to: :zone
    rename table(:listings), :original_url, to: :url
    rename table(:listings), :first_discovered, to: :first_seen_at
    rename table(:listings), :last_seen, to: :last_scraped_at
    rename table(:listings), :is_active, to: :is_delisted

    # Add new columns for group support
    alter table(:listings) do
      add :group_id, :uuid
      add :is_canonical, :boolean, default: false
      add :source_name, :string
      add :price_per_sqm, :float
      add :usable_area, :float
      add :total_floors, :integer
      add :is_private_seller, :boolean, default: false
      add :city, :string
      add :street, :string
      add :latitude, :float
      add :longitude, :float
      add :seller_name, :string
      add :seller_agency, :string
      add :seller_phone, :string
      add :property_type, :string
      add :thumbnail, :string
    end

    # Add indexes for new filterable fields
    create index(:listings, [:group_id])
    create index(:listings, [:is_canonical])
    create index(:listings, [:is_private_seller])
    create index(:listings, [:city])
    create index(:listings, [:property_type])
    create index(:listings, [:source_name])
    create index(:listings, [:is_delisted])

    # Create groups table for aggregate data
    create table(:listing_groups, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :algorithm_version, :string
      add :listing_count, :integer, default: 0
      add :min_price, :float
      add :max_price, :float
      add :min_surface, :float
      add :max_surface, :float
      add :min_price_per_sqm, :float
      add :max_price_per_sqm, :float
      add :earliest_first_seen, :utc_datetime
      add :has_top_floor, :boolean, default: false
      add :has_private_seller, :boolean, default: false
      add :group_thumbnail, :string
      add :group_district, :string
      add :group_city, :string
      add :group_zone, :string
      add :refreshed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:listing_groups, [:group_city])
    create index(:listing_groups, [:group_district])
    create index(:listing_groups, [:earliest_first_seen])

    # Create similar_groups table
    create table(:similar_groups, primary_key: false) do
      add :source_group_id, :uuid, null: false
      add :similar_group_id, :uuid, null: false
      add :similarity_score, :float
      add :match_count, :integer, default: 0
      add :algorithm_version, :string

      timestamps(type: :utc_datetime)
    end

    create index(:similar_groups, [:source_group_id])
    create index(:similar_groups, [:similar_group_id])
  end
end
