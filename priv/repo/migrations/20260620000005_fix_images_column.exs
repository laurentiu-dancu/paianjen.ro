defmodule Paianjen.Repo.Migrations.FixImagesColumn do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE listings ALTER COLUMN images TYPE text[] USING images::text[]"
  end
end
