defmodule Paianjen.Repo.Migrations.AddPriceHistoryColumns do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      # Per-listing price change points (array of maps) from little-spider export
      add :price_history, :jsonb, default: "[]"
    end

    alter table(:listing_groups) do
      # Group-level aggregated price timeline (array of maps) from little-spider export
      add :price_history, :jsonb, default: "[]"
      # Most recent price drop for the group — computed at export time, used for sorting
      add :last_price_drop_at, :utc_datetime
    end

    create index(:listing_groups, [:last_price_drop_at])
  end
end
