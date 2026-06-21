defmodule Paianjen.Listings.GroupPresenter do
  @moduledoc """
  Presents a ListingGroup + its listings in the flat format expected by the LiveView UI.
  This bridges the gap between the DB schema and the UI templates.
  """

  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Listings.Listing

  defstruct [
    :id, :city, :district, :zone, :average_price, :surface_area,
    :floor, :total_floors, :year_built, :image_url, :parking_price,
    :days_on_market, :active_listings, :total_listings,
    :listings, :health_pct, :price_per_sqm
  ]

  @doc "Convert a ListingGroup with preloaded listings into the flat group format."
  def from_group(%ListingGroup{} = group, listings) do
    active_listings = Enum.reject(listings, & &1.is_delisted)
    total_listings = length(listings)
    active_count = length(active_listings)

    canonical = Enum.find(listings, & &1.is_canonical) || List.first(listings)

    # Compute average price from active listings
    prices = Enum.map(active_listings, & &1.price) |> Enum.reject(&is_nil/1)
    avg_price = if prices != [], do: Enum.sum(prices) / length(prices), else: 0.0

    # Days on market
    earliest = group.earliest_first_seen || (canonical && canonical.first_seen_at)
    days_on_market = days_since(earliest)

    # Health percentage
    health_pct = if total_listings > 0, do: (active_count / total_listings) * 100, else: 0

    # Convert listings to the flat format
    flat_listings = Enum.map(listings, &from_listing/1)

    %__MODULE__{
      id: group.id,
      city: group.group_city || (canonical && canonical.city),
      district: group.group_district || (canonical && canonical.district),
      zone: group.group_zone || (canonical && canonical.zone),
      average_price: avg_price,
      price_per_sqm: if((canonical && canonical.surface_area) || group.min_surface > 0 and avg_price > 0,
        do: avg_price / ((canonical && canonical.surface_area) || group.min_surface),
        else: 0.0),
      surface_area: (canonical && canonical.surface_area) || group.min_surface,
      floor: canonical && canonical.floor,
      total_floors: canonical && canonical.total_floors,
      year_built: canonical && get_in(canonical.features, ["construction_year"]),
      image_url: group.group_thumbnail || (canonical && canonical.thumbnail),
      parking_price: nil,
      days_on_market: days_on_market,
      active_listings: active_count,
      total_listings: total_listings,
      listings: flat_listings,
      health_pct: health_pct
    }
  end

  defp from_listing(%Listing{} = l) do
    %{
      id: l.id,
      group_id: l.group_id,
      title: l.title,
      city: l.city,
      district: l.district,
      zone: l.zone,
      price: l.price || 0,
      price_with_vat: l.price_with_vat || l.price || 0,
      price_per_sqm: l.price_per_sqm,
      surface_area: l.surface_area,
      floor: l.floor,
      total_floors: l.total_floors,
      is_private: l.is_private_seller,
      is_delisted: l.is_delisted,
      source: l.source_name,
      url: l.url,
      image_url: l.thumbnail,
      agency_commission: l.agency_commission || 0,
      balcony_surface: l.balcony_surface,
      parking_price: l.parking_price,
      published_date: l.first_seen_at,
      delisted_date: l.delisted_date
    }
  end

  defp days_since(nil), do: 0

  defp days_since(%DateTime{} = dt) do
    DateTime.diff(DateTime.utc_now(), dt, :second) |> div(86400)
  end

  defp days_since(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> days_since()
  end
end
