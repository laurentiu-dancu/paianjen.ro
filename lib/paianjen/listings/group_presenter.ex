defmodule Paianjen.Listings.GroupPresenter do
  @moduledoc """
  Presents a ListingGroup + its listings in the flat format expected by the LiveView UI.
  This bridges the gap between the DB schema and the UI templates.
  """

  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Listings.Listing

  defstruct [
    :id, :city, :district, :zone, :min_price, :max_price,
    :min_surface, :max_surface, :rooms, :floor, :total_floors, :year_built,
    :image_url, :parking_price, :days_on_market, :days_since_last_price_drop,
    :last_price_drop_at, :active_listings,
    :total_listings, :listings, :health_pct, :has_active_listings,
    :price_history,  # group-level price change timeline (from the export)
    :first_seen_at  # DateTime when the group was first seen (for showing time when days_on_market == 0)
  ]

  @doc "Convert a ListingGroup with preloaded listings into the flat group format."
  def from_group(%ListingGroup{} = group, listings) do
    active_listings = Enum.reject(listings, & &1.is_delisted)
    total_listings = length(listings)
    active_count = length(active_listings)

    canonical = Enum.find(listings, & &1.is_canonical) || List.first(listings)

    # Compute min/max price and surface from active listings
    # Use price_with_vat (the full price buyer pays) for accurate filtering
    prices = Enum.map(active_listings, & &1.price_with_vat || &1.price) |> Enum.reject(&is_nil/1)
    surfaces = Enum.map(active_listings, & &1.surface_area) |> Enum.reject(&is_nil/1)
    min_price = if prices != [], do: Enum.min(prices), else: nil
    max_price = if prices != [], do: Enum.max(prices), else: nil
    min_surface = if surfaces != [], do: Enum.min(surfaces), else: nil
    max_surface = if surfaces != [], do: Enum.max(surfaces), else: nil

    # Days on market
    earliest = group.earliest_first_seen || (canonical && canonical.first_seen_at)
    days_on_market = days_since(earliest)

    # Days since the last price drop (0 when the group never had a price drop;
    # the template gates on last_price_drop_at being non-nil)
    days_since_last_price_drop = days_since(group.last_price_drop_at)

    # Health percentage
    health_pct = if total_listings > 0, do: (active_count / total_listings) * 100, else: 0

    # Convert listings to the flat format
    flat_listings = Enum.map(listings, &from_listing/1)

    %__MODULE__{
      id: group.id,
      city: group.group_city || (canonical && canonical.city),
      district: group.group_district || (canonical && canonical.district),
      zone: group.group_zone || (canonical && canonical.zone),
      min_price: min_price,
      max_price: max_price,
      min_surface: min_surface,
      max_surface: max_surface,
      rooms: canonical && canonical.rooms,
      floor: canonical && canonical.floor,
      total_floors: canonical && canonical.total_floors,
      year_built: canonical && get_in(canonical.features, ["construction_year"]),
      image_url: group.group_thumbnail || (canonical && canonical.thumbnail),
      parking_price: canonical && canonical.parking_price,
      days_on_market: days_on_market,
      days_since_last_price_drop: days_since_last_price_drop,
      last_price_drop_at: group.last_price_drop_at,
      active_listings: active_count,
      total_listings: total_listings,
      has_active_listings: group.has_active_listings,
      listings: flat_listings,
      health_pct: health_pct,
      price_history: group.price_history || [],
      first_seen_at: earliest
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
      vat_included: l.vat_included,
      price_per_sqm: l.price_per_sqm,
      surface_area: l.surface_area,
      rooms: l.rooms,
      floor: l.floor,
      total_floors: l.total_floors,
      is_private: l.is_private_seller,
      is_delisted: l.is_delisted,
      source: l.source_name,
      url: l.url,
      image_url: l.thumbnail,
      images: l.images || [],
      agency_commission: l.agency_commission || 0,
      balcony_surface: l.balcony_surface,
      parking_price: l.parking_price,
      published_date: l.first_seen_at,
      delisted_date: l.delisted_date
    }
  end

  defp days_since(nil), do: 0

  defp days_since(%DateTime{} = dt) do
    Date.diff(Date.utc_today(), DateTime.to_date(dt))
  end

  defp days_since(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> days_since()
  end
end
