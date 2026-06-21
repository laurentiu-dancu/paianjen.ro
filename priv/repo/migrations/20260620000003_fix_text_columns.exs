defmodule Paianjen.Repo.Migrations.FixTextColumns do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE listing_groups ALTER COLUMN group_thumbnail TYPE text"
    execute "ALTER TABLE listing_groups ALTER COLUMN group_zone TYPE text"
  end
end
