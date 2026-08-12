defmodule Paianjen.Repo.Migrations.CreateWishlists do
  use Ecto.Migration

  def change do
    create table(:wishlists, primary_key: false) do
      # The public share uuid (/colectii/:id). DB-generated so the row can be
      # created from any SQL path; Ecto usually supplies it explicitly.
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      timestamps(type: :utc_datetime)
    end

    create table(:wishlist_items, primary_key: false) do
      add :wishlist_id,
          references(:wishlists, type: :uuid, on_delete: :delete_all),
          primary_key: true

      # NOTE: deliberately NO foreign key to listing_groups. The import
      # pipeline's cleanup_orphans deletes groups wholesale; a hard FK would
      # either fail the import or cascade-delete wishlist items. The read path
      # simply skips groups that no longer exist (inner join).
      add :group_id, :uuid, primary_key: true

      add :added_at, :utc_datetime, default: fragment("now()")
    end

    create index(:wishlist_items, [:wishlist_id, :added_at])
  end
end
