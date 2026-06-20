defmodule Paianjen.Listings do
  @moduledoc """
  The Listings context.
  """
  import Ecto.Query, warn: false
  alias Paianjen.Repo
  alias Paianjen.Listings.Listing

  def list_listings(opts \\ []) do
    Listing
    |> filter_active(opts)
    |> filter_by_seller_type(opts)
    |> filter_by_rooms(opts)
    |> filter_by_district(opts)
    |> filter_by_price_range(opts)
    |> order_by([l], asc: l.first_discovered)
    |> Repo.all()
  end

  def get_listing!(id), do: Repo.get!(Listing, id)

  def create_listing(attrs \\ %{}) do
    %Listing{}
    |> Listing.changeset(attrs)
    |> Repo.insert()
  end

  def update_listing(%Listing{} = listing, attrs) do
    listing
    |> Listing.changeset(attrs)
    |> Repo.update()
  end

  def delete_listing(%Listing{} = listing) do
    Repo.delete(listing)
  end

  def change_listing(%Listing{} = listing, attrs \\ %{}) do
    Listing.changeset(listing, attrs)
  end

  # ---- Filters ----

  defp filter_active(query, opts) do
    case Keyword.get(opts, :active_only, true) do
      true -> where(query, [l], l.is_active == true)
      false -> query
    end
  end

  defp filter_by_seller_type(query, opts) do
    case Keyword.get(opts, :seller_type) do
      nil -> query
      "" -> query
      type -> where(query, [l], l.seller_type == ^type)
    end
  end

  defp filter_by_rooms(query, opts) do
    case Keyword.get(opts, :rooms) do
      nil -> query
      rooms -> where(query, [l], l.rooms == ^rooms)
    end
  end

  defp filter_by_district(query, opts) do
    case Keyword.get(opts, :district) do
      nil -> query
      "" -> query
      district -> where(query, [l], l.district == ^district)
    end
  end

  defp filter_by_price_range(query, opts) do
    query
    |> maybe_filter_min_price(Keyword.get(opts, :min_price))
    |> maybe_filter_max_price(Keyword.get(opts, :max_price))
  end

  defp maybe_filter_min_price(query, nil), do: query
  defp maybe_filter_min_price(query, min_price) do
    where(query, [l], l.price >= ^min_price)
  end

  defp maybe_filter_max_price(query, nil), do: query
  defp maybe_filter_max_price(query, max_price) do
    where(query, [l], l.price <= ^max_price)
  end
end
