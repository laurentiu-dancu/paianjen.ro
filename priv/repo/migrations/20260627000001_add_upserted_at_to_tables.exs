defmodule Paianjen.Repo.Migrations.AddUpsertedAtToTables do
  use Ecto.Migration

  def change do
    alter table(:listing_groups) do
      add :upserted_at, :utc_datetime
    end

    alter table(:listings) do
      add :upserted_at, :utc_datetime
    end

    alter table(:similar_groups) do
      add :upserted_at, :utc_datetime
    end

    create index(:listing_groups, [:upserted_at])
    create index(:listings, [:upserted_at])
    create index(:similar_groups, [:upserted_at])
  end
end
