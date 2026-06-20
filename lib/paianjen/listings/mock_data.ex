defmodule Paianjen.Listings.MockData do
  @moduledoc """
  Mock data for listings — replaces DB until backend logic is added.
  Ported from the React project's mockListings.ts
  """

  defstruct [
    :id,
    :group_id,
    :title,
    :city,
    :district,
    :zone,
    :price,
    :price_with_vat,
    :parking_price,
    :price_per_sqm,
    :surface_area,
    :agency_commission,
    :floor,
    :total_floors,
    :year_built,
    :balcony_surface,
    :published_date,
    :delisted_date,
    :is_private,
    :source,
    :image_url
  ]

  defmodule Listing do
    defstruct [
      :id,
      :group_id,
      :title,
      :city,
      :district,
      :zone,
      :price,
      :price_with_vat,
      :parking_price,
      :price_per_sqm,
      :surface_area,
      :agency_commission,
      :floor,
      :total_floors,
      :year_built,
      :balcony_surface,
      :published_date,
      :delisted_date,
      :is_private,
      :source,
      :image_url
    ]
  end

  defmodule ListingGroup do
    defstruct [
      :id,
      :listings,
      :active_listings,
      :total_listings,
      :oldest_published_date,
      :days_on_market,
      :city,
      :district,
      :zone,
      :average_price,
      :surface_area,
      :parking_price,
      :floor,
      :total_floors,
      :year_built,
      :image_url
    ]
  end

  @doc "Returns all mock listings"
  def all_listings do
    [
      # Group 1 - 45 days on market
      %Listing{
        id: "l1",
        group_id: "g1",
        title: "Apartament 2 camere, Ultracentral, etaj 3/4, 60mp, finisat lux, fără comision",
        city: "Cluj-Napoca",
        district: "Centru",
        zone: "Ultracentral",
        price: 142_000,
        price_with_vat: 142_000,
        parking_price: 15_000,
        price_per_sqm: 2367,
        surface_area: 60,
        agency_commission: 0,
        floor: 3,
        total_floors: 4,
        year_built: 2019,
        balcony_surface: 5,
        published_date: days_ago(45),
        is_private: true,
        source: "Proprietar direct",
        image_url: "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200"
      },
      %Listing{
        id: "l2",
        group_id: "g1",
        title: "Vând apartament 2 camere Centru Cluj, 60mp util, bloc 2019, parcare inclusa",
        city: "Cluj-Napoca",
        district: "Centru",
        zone: "Ultracentral",
        price: 145_000,
        price_with_vat: 145_000,
        price_per_sqm: 2417,
        surface_area: 60,
        agency_commission: 4350,
        floor: 3,
        total_floors: 4,
        year_built: 2019,
        balcony_surface: 5,
        published_date: days_ago(38),
        is_private: false,
        source: "Prima Imobiliare",
        image_url: "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200"
      },
      %Listing{
        id: "l3",
        group_id: "g1",
        title: "AP 2 cam ultracentral Cluj-Napoca, 60 mp, etaj 3, constructie noua",
        city: "Cluj-Napoca",
        district: "Centru",
        zone: "Ultracentral",
        price: 148_000,
        price_with_vat: 148_000,
        price_per_sqm: 2467,
        surface_area: 60,
        agency_commission: 2960,
        floor: 3,
        total_floors: 4,
        published_date: days_ago(32),
        delisted_date: days_ago(5),
        is_private: false,
        source: "OLX.ro",
        image_url: "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=1200"
      },
      # Group 2 - 5 days on market
      %Listing{
        id: "l4",
        group_id: "g2",
        title: "Apartament 2 camere, 60mp, etaj 2/10, Mănăștur – Complex Vivo, comision 0",
        city: "Cluj-Napoca",
        district: "Mănăștur",
        zone: "Complex Vivo",
        price: 95_000,
        price_with_vat: 95_000,
        price_per_sqm: 1583,
        surface_area: 60,
        agency_commission: 0,
        floor: 2,
        total_floors: 10,
        year_built: 2021,
        balcony_surface: 8,
        published_date: days_ago(5),
        is_private: false,
        source: "Developer – Comision 0",
        image_url: "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200"
      },
      %Listing{
        id: "l5",
        group_id: "g2",
        title: "2 camere Manastur, bloc nou 2021, balcon 8mp, vedere spre parc",
        city: "Cluj-Napoca",
        district: "Mănăștur",
        zone: "Complex Vivo",
        price: 98_000,
        price_with_vat: 98_000,
        price_per_sqm: 1633,
        surface_area: 60,
        agency_commission: 2450,
        floor: 2,
        total_floors: 10,
        year_built: 2021,
        published_date: days_ago(3),
        is_private: false,
        source: "Imobiliare.ro",
        image_url: "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=1200"
      },
      # Group 3 - 62 days, multiple delisted
      %Listing{
        id: "l6",
        group_id: "g3",
        title: "Apartament 3 camere Gheorgheni, zona FSEGA, 70mp, parcare subterana, etaj 1",
        city: "Cluj-Napoca",
        district: "Gheorgheni",
        zone: "Zona FSEGA",
        price: 120_000,
        price_with_vat: 120_000,
        parking_price: 12_000,
        price_per_sqm: 1714,
        surface_area: 70,
        agency_commission: 3600,
        floor: 1,
        total_floors: 4,
        year_built: 2015,
        balcony_surface: 6,
        published_date: days_ago(62),
        is_private: false,
        source: "Storia.ro",
        image_url: "https://images.unsplash.com/photo-1502672260066-6bc04846e05e?w=1200"
      },
      %Listing{
        id: "l7",
        group_id: "g3",
        title: "3 camere, 70mp util, Gheorgheni Cluj, bloc 2015, et.1, finisat modern",
        city: "Cluj-Napoca",
        district: "Gheorgheni",
        zone: "Zona FSEGA",
        price: 118_000,
        price_with_vat: 118_000,
        price_per_sqm: 1686,
        surface_area: 70,
        agency_commission: 2360,
        floor: 1,
        total_floors: 4,
        published_date: days_ago(55),
        delisted_date: days_ago(12),
        is_private: false,
        source: "Imobiliare.ro",
        image_url: "https://images.unsplash.com/photo-1502672260066-6bc04846e05e?w=1200"
      },
      %Listing{
        id: "l8",
        group_id: "g3",
        title: "VÂND ap. 3 camere Gheorgheni, 70mp, aproape de FSEGA, etaj 1/4",
        city: "Cluj-Napoca",
        district: "Gheorgheni",
        zone: "Zona FSEGA",
        price: 122_000,
        price_with_vat: 122_000,
        price_per_sqm: 1743,
        surface_area: 70,
        agency_commission: 4270,
        floor: 1,
        total_floors: 4,
        published_date: days_ago(48),
        delisted_date: days_ago(8),
        is_private: false,
        source: "OLX.ro",
        image_url: "https://images.unsplash.com/photo-1502672260066-6bc04846e05e?w=1200"
      },
      %Listing{
        id: "l9",
        group_id: "g3",
        title: "Proprietar – 3 camere Gheorgheni 70mp, fără agenție, negociabil",
        city: "Cluj-Napoca",
        district: "Gheorgheni",
        zone: "Zona FSEGA",
        price: 119_500,
        price_with_vat: 119_500,
        price_per_sqm: 1707,
        surface_area: 70,
        agency_commission: 0,
        floor: 1,
        total_floors: 4,
        published_date: days_ago(40),
        is_private: true,
        source: "Proprietar direct",
        image_url: "https://images.unsplash.com/photo-1502672260066-6bc04846e05e?w=1200"
      },
      # Group 4 - 2 days
      %Listing{
        id: "l10",
        group_id: "g4",
        title: "Apartament 3 camere Bună Ziua, 80mp, etaj 5/8, parcare, bloc 2022, balcon 10mp",
        city: "Cluj-Napoca",
        district: "Bună Ziua",
        zone: "Zona Iulius Mall",
        price: 180_000,
        price_with_vat: 180_000,
        parking_price: 18_000,
        price_per_sqm: 2250,
        surface_area: 80,
        agency_commission: 3600,
        floor: 5,
        total_floors: 8,
        year_built: 2022,
        balcony_surface: 10,
        published_date: days_ago(2),
        is_private: false,
        source: "Prima Imobiliare",
        image_url: "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200"
      },
      # Group 5 - 95 days
      %Listing{
        id: "l11",
        group_id: "g5",
        title: "Ap 2 camere Zorilor Cluj, 52,5mp, et.7/10, vedere panoramica, an 2008",
        city: "Cluj-Napoca",
        district: "Zorilor",
        zone: "Observatorului",
        price: 135_000,
        price_with_vat: 135_000,
        price_per_sqm: 2571,
        surface_area: 52.5,
        agency_commission: 4050,
        floor: 7,
        total_floors: 10,
        year_built: 2008,
        balcony_surface: 4,
        published_date: days_ago(95),
        is_private: false,
        source: "OLX.ro",
        image_url: "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=1200"
      },
      %Listing{
        id: "l12",
        group_id: "g5",
        title: "2 camere, 52mp, Zorilor, etaj 7, luminoasa, living mare",
        city: "Cluj-Napoca",
        district: "Zorilor",
        zone: "Observatorului",
        price: 138_000,
        price_with_vat: 138_000,
        price_per_sqm: 2629,
        surface_area: 52.5,
        agency_commission: 3450,
        floor: 7,
        total_floors: 10,
        year_built: 2008,
        published_date: days_ago(87),
        delisted_date: days_ago(20),
        is_private: false,
        source: "Storia.ro",
        image_url: "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=1200"
      },
      %Listing{
        id: "l13",
        group_id: "g5",
        title: "PROPRIETAR – 2 cam. Zorilor, 52.5mp, et.7, fara comision agentie, pret negociabil",
        city: "Cluj-Napoca",
        district: "Zorilor",
        zone: "Observatorului",
        price: 132_000,
        price_with_vat: 132_000,
        price_per_sqm: 2514,
        surface_area: 52.5,
        agency_commission: 0,
        floor: 7,
        total_floors: 10,
        year_built: 2008,
        published_date: days_ago(78),
        is_private: true,
        source: "Proprietar direct",
        image_url: "https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=1200"
      },
      # Group 6 - 12 days, Florești
      %Listing{
        id: "l14",
        group_id: "g6",
        title: "Apartament 2 camere Florești, str. Avram Iancu, 55mp, etaj 3/4, parcare",
        city: "Florești",
        district: "Florești",
        zone: "Centru Florești",
        price: 78_000,
        price_with_vat: 78_000,
        parking_price: 8_000,
        price_per_sqm: 1418,
        surface_area: 55,
        agency_commission: 2340,
        floor: 3,
        total_floors: 4,
        year_built: 2018,
        balcony_surface: 5,
        published_date: days_ago(12),
        is_private: false,
        source: "Imobiliare.ro",
        image_url: "https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200"
      },
      %Listing{
        id: "l15",
        group_id: "g6",
        title: "2 cam. Floresti, 55mp, finisat complet, bloc nou, comision 0 cumparator",
        city: "Florești",
        district: "Florești",
        zone: "Centru Florești",
        price: 79_500,
        price_with_vat: 79_500,
        price_per_sqm: 1445,
        surface_area: 55,
        agency_commission: 0,
        floor: 3,
        total_floors: 4,
        year_built: 2018,
        published_date: days_ago(8),
        is_private: false,
        source: "Storia.ro",
        image_url: "https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=1200"
      }
    ]
  end

  @doc "Returns all listing groups, sorted by days on market (newest first)"
  def all_groups do
    all_listings()
    |> Enum.group_by(& &1.group_id)
    |> Enum.map(fn {group_id, listings} ->
      active_listings = Enum.reject(listings, & &1.delisted_date)
      oldest_date = listings |> Enum.map(& &1.published_date) |> Enum.min()
      days_on_market = Date.diff(Date.utc_today(), oldest_date)

      avg_price =
        if length(active_listings) > 0 do
          Enum.sum(Enum.map(active_listings, & &1.price_with_vat)) / length(active_listings)
        else
          Enum.sum(Enum.map(listings, & &1.price_with_vat)) / length(listings)
        end

      parking_listing = Enum.find(active_listings, & &1.parking_price)
      representative = hd(listings)

      %ListingGroup{
        id: group_id,
        listings: listings,
        active_listings: length(active_listings),
        total_listings: length(listings),
        oldest_published_date: oldest_date,
        days_on_market: days_on_market,
        city: representative.city,
        district: representative.district,
        zone: representative.zone,
        average_price: avg_price,
        surface_area: representative.surface_area,
        parking_price: parking_listing && parking_listing.parking_price,
        floor: representative.floor,
        total_floors: representative.total_floors,
        year_built: representative.year_built,
        image_url: representative.image_url
      }
    end)
    |> Enum.sort_by(& &1.days_on_market, :asc)
  end

  @doc "Returns all unique cities"
  def all_cities do
    all_listings()
    |> Enum.map(& &1.city)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Returns all unique districts"
  def all_districts do
    all_listings()
    |> Enum.map(& &1.district)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "Finds a group by id"
  def get_group(id) do
    all_groups() |> Enum.find(&(&1.id == id))
  end

  defp days_ago(days) do
    Date.add(Date.utc_today(), -days)
  end
end
