defmodule Paianjen.Repo.Migrations.AddFullTextSearch do
  use Ecto.Migration

  def up do
    # Add tsvector column for full-text search on title + description
    alter table(:listings) do
      add :search_vector, :tsvector, null: true
    end

    # Create GIN index for fast full-text search
    execute "CREATE INDEX IF NOT EXISTS idx_listings_search_vector ON listings USING GIN (search_vector)"

    # Create function to auto-update search_vector
    execute """
    CREATE OR REPLACE FUNCTION listings_search_vector_update() RETURNS trigger AS $$
    BEGIN
      NEW.search_vector :=
        setweight(to_tsvector('romanian', COALESCE(NEW.title, '')), 'A') ||
        setweight(to_tsvector('romanian', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('romanian', COALESCE(NEW.city, '')), 'C') ||
        setweight(to_tsvector('romanian', COALESCE(NEW.district, '')), 'C') ||
        setweight(to_tsvector('romanian', COALESCE(NEW.zone, '')), 'C');
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    # Create trigger to auto-update search_vector
    execute """
    CREATE TRIGGER trg_listings_search_vector
    BEFORE INSERT OR UPDATE ON listings
    FOR EACH ROW
    EXECUTE FUNCTION listings_search_vector_update();
    """

    # Populate existing rows
    execute """
    UPDATE listings SET search_vector =
      setweight(to_tsvector('romanian', COALESCE(title, '')), 'A') ||
      setweight(to_tsvector('romanian', COALESCE(description, '')), 'B') ||
      setweight(to_tsvector('romanian', COALESCE(city, '')), 'C') ||
      setweight(to_tsvector('romanian', COALESCE(district, '')), 'C') ||
      setweight(to_tsvector('romanian', COALESCE(zone, '')), 'C');
    """

    # Add composite indexes for common filter combinations
    execute "CREATE INDEX IF NOT EXISTS idx_listings_group_city_district ON listing_groups (group_city, group_district)"
    execute "CREATE INDEX IF NOT EXISTS idx_listings_group_min_price ON listing_groups (min_price)"
    execute "CREATE INDEX IF NOT EXISTS idx_listings_group_min_surface ON listing_groups (min_surface)"
    execute "CREATE INDEX IF NOT EXISTS idx_listings_is_delisted ON listings (is_delisted)"
    execute "CREATE INDEX IF NOT EXISTS idx_listings_price ON listings (price)"
    execute "CREATE INDEX IF NOT EXISTS idx_listings_surface ON listings (surface_area)"
  end

  def down do
    execute "DROP TRIGGER IF EXISTS trg_listings_search_vector ON listings"
    execute "DROP FUNCTION IF EXISTS listings_search_vector_update()"
    drop index(:listings, [:search_vector])
    alter table(:listings) do
      remove :search_vector
    end
    execute "DROP INDEX IF EXISTS idx_listings_group_city_district"
    execute "DROP INDEX IF EXISTS idx_listings_group_min_price"
    execute "DROP INDEX IF EXISTS idx_listings_group_min_surface"
    execute "DROP INDEX IF EXISTS idx_listings_is_delisted"
    execute "DROP INDEX IF EXISTS idx_listings_price"
    execute "DROP INDEX IF EXISTS idx_listings_surface"
  end
end
