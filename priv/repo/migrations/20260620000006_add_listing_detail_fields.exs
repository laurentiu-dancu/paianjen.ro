defmodule Paianjen.Repo.Migrations.AddListingDetailFields do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :agency_commission, :integer, default: 0
      add :balcony_surface, :float
      add :parking_price, :integer
      add :delisted_date, :utc_datetime
      add :price_with_vat, :integer
    end
  end
end
