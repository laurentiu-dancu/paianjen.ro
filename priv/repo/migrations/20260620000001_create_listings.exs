defmodule Paianjen.Repo.Migrations.CreateListings do
  use Ecto.Migration

  def change do
    create table(:listings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :price, :integer, null: false
      add :currency, :string, default: "EUR"
      add :rooms, :integer
      add :surface, :float
      add :floor, :integer
      add :seller_type, :string, null: false, default: "private"
      add :district, :string
      add :neighborhood, :string
      add :original_url, :string
      add :first_discovered, :utc_datetime
      add :last_seen, :utc_datetime
      add :is_active, :boolean, default: true
      add :images, {:array, :string}, default: []
      add :features, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:listings, [:seller_type])
    create index(:listings, [:district])
    create index(:listings, [:rooms])
    create index(:listings, [:price])
    create index(:listings, [:is_active])
    create index(:listings, [:first_discovered])
  end
end
