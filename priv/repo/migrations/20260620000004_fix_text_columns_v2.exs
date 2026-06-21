defmodule Paianjen.Repo.Migrations.FixTextColumnsV2 do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE listings ALTER COLUMN description TYPE text"
    execute "ALTER TABLE listings ALTER COLUMN thumbnail TYPE text"
    execute "ALTER TABLE listing_groups ALTER COLUMN group_thumbnail TYPE text"
    execute "ALTER TABLE listing_groups ALTER COLUMN group_zone TYPE text"
  end
end
