defmodule Paianjen.Repo.Migrations.AddVatIncludedToListings do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :vat_included, :boolean, default: false
    end

    create index(:listings, [:vat_included])
  end
end
