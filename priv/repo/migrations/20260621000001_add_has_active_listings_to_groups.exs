defmodule Paianjen.Repo.Migrations.AddHasActiveListingsToGroups do
  use Ecto.Migration

  def change do
    alter table(:listing_groups) do
      add :has_active_listings, :boolean, default: false, null: false
    end

    create index(:listing_groups, [:has_active_listings], name: :idx_listing_groups_has_active_listings)
  end
end
