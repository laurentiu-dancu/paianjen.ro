defmodule Paianjen.Repo.Migrations.AddCursorIndexToListingGroups do
  use Ecto.Migration

  def change do
    # Composite index for cursor-based lookup: ordering by earliest_first_seen desc, then id
    # This supports the "resolve cursor" query that counts groups before a given group
    execute "CREATE INDEX IF NOT EXISTS idx_listing_groups_cursor ON listing_groups (earliest_first_seen DESC, id)"
  end
end
