defmodule Paianjen.Listings do
  @moduledoc """
  The Listings context — manages listing groups, individual listings, and similar groups.
  """
  import Ecto.Query, warn: false
  alias Paianjen.Repo
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Listings.SimilarGroup

  # ---- Listing Groups ----

  def list_groups(opts \\ []) do
    ListingGroup
    |> filter_by_city(opts)
    |> filter_by_district(opts)
    |> order_by([g], desc: g.earliest_first_seen)
    |> Repo.all()
    |> Repo.preload(:listings)
  end

  def get_group!(id) do
    Repo.get!(ListingGroup, id)
    |> Repo.preload(:listings)
  end

  def create_group(attrs \\ %{}) do
    %ListingGroup{}
    |> ListingGroup.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_group(attrs) do
    case Repo.get(ListingGroup, attrs[:id] || attrs["id"]) do
      nil ->
        create_group(attrs)
      group ->
        group
        |> ListingGroup.changeset(attrs)
        |> Repo.update()
    end
  end

  # ---- Listings ----

  def get_listing!(id), do: Repo.get!(Listing, id)

  def create_listing(attrs \\ %{}) do
    %Listing{}
    |> Listing.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_listing(attrs) do
    id = attrs[:id] || attrs["id"]
    case Repo.get(Listing, id) do
      nil ->
        create_listing(attrs)
      listing ->
        listing
        |> Listing.changeset(attrs)
        |> Repo.update()
    end
  end

  def delete_listing(%Listing{} = listing), do: Repo.delete(listing)

  def list_listings_for_group(group_id) do
    Listing
    |> where([l], l.group_id == ^group_id)
    |> order_by([l], desc: l.is_canonical, asc: l.first_seen_at)
    |> Repo.all()
  end

  # ---- Similar Groups ----

  def create_similar_group(attrs \\ %{}) do
    %SimilarGroup{}
    |> SimilarGroup.changeset(attrs)
    |> Repo.insert()
  end

  def list_similar_groups(group_id) do
    SimilarGroup
    |> where([sg], sg.source_group_id == ^group_id)
    |> order_by([sg], desc: sg.similarity_score)
    |> Repo.all()
  end

  # ---- Import (bulk from JSONL) ----

  def import_group_with_listings(group_data, listings_data) do
    Repo.transaction(fn ->
      # Upsert group
      group_attrs = %{
        id: group_data["entity_id"],
        algorithm_version: group_data["algorithm_version"],
        refreshed_at: parse_datetime(group_data["refreshed_at"]),
        inserted_at: parse_datetime(group_data["created_at"]),
        updated_at: parse_datetime(group_data["refreshed_at"])
      }

      group_attrs = group_attrs
      |> put_if_present(:group_city, canonical_listing_city(listings_data))
      |> put_if_present(:group_district, canonical_listing_district(listings_data))
      |> put_if_present(:group_zone, canonical_listing_zone(listings_data))
      |> put_if_present(:group_thumbnail, canonical_listing_thumbnail(listings_data))
      |> then(fn attrs ->
        prices = Enum.map(listings_data, & &1["price"]) |> Enum.reject(&is_nil/1)
        surfaces = Enum.map(listings_data, & &1["surface_area"]) |> Enum.reject(&is_nil/1)
        ppsqm = Enum.map(listings_data, & &1["price_per_sqm"]) |> Enum.reject(&is_nil/1)
        first_seens = Enum.map(listings_data, &parse_datetime(&1["first_seen_at"])) |> Enum.reject(&is_nil/1)

        attrs
        |> put_if_present(:listing_count, length(listings_data))
        |> put_if_present(:min_price, Enum.min(prices, fn -> nil end))
        |> put_if_present(:max_price, Enum.max(prices, fn -> nil end))
        |> put_if_present(:min_surface, Enum.min(surfaces, fn -> nil end))
        |> put_if_present(:max_surface, Enum.max(surfaces, fn -> nil end))
        |> put_if_present(:min_price_per_sqm, Enum.min(ppsqm, fn -> nil end))
        |> put_if_present(:max_price_per_sqm, Enum.max(ppsqm, fn -> nil end))
        |> put_if_present(:earliest_first_seen, Enum.min(first_seens, fn -> nil end))
        |> then(fn a ->
          has_top = Enum.any?(listings_data, fn l ->
            l["floor"] != nil and l["total_floors"] != nil and l["floor"] == l["total_floors"]
          end)
          has_private = Enum.any?(listings_data, & &1["is_private_seller"])
          a
          |> Map.put(:has_top_floor, has_top)
          |> Map.put(:has_private_seller, has_private)
        end)
      end)

      {:ok, group} = upsert_group(group_attrs)

      # Upsert listings
      Enum.each(listings_data, fn l_attrs ->
        listing_map = %{
          id: l_attrs["listing_id"],
          group_id: group_data["entity_id"],
          is_canonical: l_attrs["is_canonical"] || false,
          source_name: l_attrs["source_name"],
          title: l_attrs["title"],
          description: l_attrs["description"],
          price: l_attrs["price"] && round(l_attrs["price"]),
          price_per_sqm: l_attrs["price_per_sqm"],
          rooms: l_attrs["rooms"],
          surface_area: l_attrs["surface_area"],
          usable_area: l_attrs["usable_area"],
          floor: l_attrs["floor"],
          total_floors: l_attrs["total_floors"],
          is_private_seller: l_attrs["is_private_seller"] || false,
          is_delisted: l_attrs["is_delisted"] || false,
          district: l_attrs["district"],
          zone: l_attrs["zone"],
          city: l_attrs["city"],
          street: l_attrs["street"],
          latitude: l_attrs["latitude"],
          longitude: l_attrs["longitude"],
          url: l_attrs["url"],
          first_seen_at: parse_datetime(l_attrs["first_seen_at"]),
          last_scraped_at: parse_datetime(l_attrs["last_scraped_at"]),
          seller_name: l_attrs["seller_name"],
          seller_agency: l_attrs["seller_agency"],
          seller_phone: l_attrs["seller_phone"],
          property_type: l_attrs["property_type"],
          thumbnail: l_attrs["thumbnail"],
          images: extract_image_urls(l_attrs["images"]),
          features: l_attrs["features"] || %{},
          agency_commission: l_attrs["agency_commission"] && round(l_attrs["agency_commission"]),
          balcony_surface: l_attrs["balcony_surface"],
          parking_price: l_attrs["parking_price"],
          delisted_date: parse_datetime(l_attrs["delisted_date"]),
          price_with_vat: l_attrs["price_with_vat"] && round(l_attrs["price_with_vat"])
        }

        upsert_listing(listing_map)
      end)

      # Upsert similar groups
      Enum.each(group_data["similar_groups"] || [], fn sg ->
        sg_attrs = %{
          source_group_id: group_data["entity_id"],
          similar_group_id: sg["entity_id"],
          similarity_score: sg["similarity_score"],
          match_count: sg["match_count"]
        }

        case Repo.get_by(SimilarGroup, source_group_id: sg_attrs.source_group_id, similar_group_id: sg_attrs.similar_group_id) do
          nil -> create_similar_group(sg_attrs)
          existing ->
            existing
            |> SimilarGroup.changeset(sg_attrs)
            |> Repo.update()
        end
      end)

      group
    end)
  end

  # ---- Filter helpers for groups ----

  defp filter_by_city(query, opts) do
    case Keyword.get(opts, :city) do
      nil -> query
      "" -> query
      city -> where(query, [g], g.group_city == ^city)
    end
  end

  defp filter_by_district(query, opts) do
    case Keyword.get(opts, :district) do
      nil -> query
      "" -> query
      district -> where(query, [g], g.group_district == ^district)
    end
  end

  # ---- Private helpers ----

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp canonical_listing_city(listings) do
    case Enum.find(listings, & &1["is_canonical"]) do
      nil -> case listings do [h | _] -> h["city"]; _ -> nil end
      l -> l["city"]
    end
  end

  defp canonical_listing_district(listings) do
    case Enum.find(listings, & &1["is_canonical"]) do
      nil -> case listings do [h | _] -> h["district"]; _ -> nil end
      l -> l["district"]
    end
  end

  defp canonical_listing_zone(listings) do
    case Enum.find(listings, & &1["is_canonical"]) do
      nil -> case listings do [h | _] -> h["zone"]; _ -> nil end
      l -> l["zone"]
    end
  end

  defp canonical_listing_thumbnail(listings) do
    case Enum.find(listings, & &1["is_canonical"]) do
      nil -> case listings do [h | _] -> h["thumbnail"]; _ -> nil end
      l -> l["thumbnail"]
    end
  end

  defp extract_image_urls(nil), do: []
  defp extract_image_urls(images) when is_list(images) do
    Enum.map(images, & &1["source_url"])
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  defp parse_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> dt
      {:error, _} ->
        case NaiveDateTime.from_iso8601(iso_string) do
          {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
          {:error, _} -> nil
        end
    end
  end
end
