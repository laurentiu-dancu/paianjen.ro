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
    |> filter_by_active(opts)
    |> filter_by_city(opts)
    |> filter_by_district(opts)
    |> filter_by_min_price(opts)
    |> filter_by_max_price(opts)
    |> filter_by_min_surface(opts)
    |> filter_by_max_surface(opts)
    |> filter_by_parking(opts)
    |> filter_by_commission(opts)
    |> filter_by_search(opts)
    |> order_by([g], desc: g.earliest_first_seen, asc: g.id)
    |> Repo.all()
    |> Repo.preload(:listings)
  end

  def list_groups_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 20)
    offset = Keyword.get(opts, :offset, (page - 1) * page_size)

    base_query =
      ListingGroup
      |> filter_by_active(opts)
      |> filter_by_city(opts)
      |> filter_by_district(opts)
      |> filter_by_min_price(opts)
      |> filter_by_max_price(opts)
      |> filter_by_min_surface(opts)
      |> filter_by_max_surface(opts)
      |> filter_by_parking(opts)
      |> filter_by_commission(opts)
      |> filter_by_search(opts)

    total_count = Repo.aggregate(base_query, :count, :id)

    groups =
      base_query
      |> order_by([g], desc: g.earliest_first_seen, asc: g.id)
      |> limit(^page_size)
      |> offset(^offset)
      |> Repo.all()
      |> Repo.preload(:listings)

    %{
      groups: groups,
      total_count: total_count,
      page: page,
      page_size: page_size,
      total_pages: ceil(total_count / page_size),
      has_more: page * page_size < total_count
    }
  end

  def get_group!(id) do
    Repo.get!(ListingGroup, id)
    |> Repo.preload(:listings)
  end

  @doc """
  Resolves a cursor (group_id) to an offset and page number.
  Returns {offset, page} so the cursor group appears first in the results.
  Falls back to {0, 1} if the group is not found.
  """
  def resolve_cursor(cursor_id, opts \\ []) do
    case Repo.get(ListingGroup, cursor_id) do
      nil ->
        {0, 1}

      group ->
        base_query =
          ListingGroup
          |> filter_by_active(opts)
          |> filter_by_city(opts)
          |> filter_by_district(opts)
          |> filter_by_min_price(opts)
          |> filter_by_max_price(opts)
          |> filter_by_min_surface(opts)
          |> filter_by_max_surface(opts)
          |> filter_by_parking(opts)
          |> filter_by_commission(opts)
          |> filter_by_search(opts)

        # Count how many groups come before this one (earliest_first_seen DESC, id ASC)
        position =
          base_query
          |> where(
            [g],
            g.earliest_first_seen > ^group.earliest_first_seen or
              (g.earliest_first_seen == ^group.earliest_first_seen and g.id > ^group.id)
          )
          |> Repo.aggregate(:count, :id)

        page_size = Keyword.get(opts, :page_size, 20)
        page = div(position, page_size) + 1
        {position, page}
    end
  end

  @doc """
  Loads up to `limit` groups that are newer than (come before) the cursor group.
  Returns {groups, has_more} where groups are ordered newest-first.
  Returns {[], false} if the cursor group is not found or no newer groups exist.
  """
  def list_groups_before_cursor(cursor_id, opts \\ []) do
    limit = Keyword.get(opts, :page_size, 20)

    case Repo.get(ListingGroup, cursor_id) do
      nil ->
        {[], false}

      group ->
        base_query =
          ListingGroup
          |> filter_by_active(opts)
          |> filter_by_city(opts)
          |> filter_by_district(opts)
          |> filter_by_min_price(opts)
          |> filter_by_max_price(opts)
          |> filter_by_min_surface(opts)
          |> filter_by_max_surface(opts)
          |> filter_by_parking(opts)
          |> filter_by_commission(opts)
          |> filter_by_search(opts)

        # Groups that come BEFORE the cursor in the sort order (newer items)
        # Sort is: earliest_first_seen DESC, id ASC
        # "Before" = higher earliest_first_seen, or same date with higher id
        newer_query =
          base_query
          |> where(
            [g],
            g.earliest_first_seen > ^group.earliest_first_seen or
              (g.earliest_first_seen == ^group.earliest_first_seen and g.id > ^group.id)
          )
          |> order_by([g], desc: g.earliest_first_seen, asc: g.id)
          |> limit(^limit + 1)

        all_groups = Repo.all(newer_query) |> Repo.preload(:listings)

        {groups, has_more} =
          if length(all_groups) > limit do
            {Enum.take(all_groups, limit), true}
          else
            {all_groups, false}
          end

        {groups, has_more}
    end
  end

  @doc "Returns distinct cities and districts with their group counts, ordered by count desc."
  def list_cities_and_districts do
    ListingGroup
    |> where([g], g.has_active_listings == true)
    |> where([g], not is_nil(g.group_city) or not is_nil(g.group_district))
    |> group_by([g], [g.group_city, g.group_district])
    |> select([g], %{
      city: g.group_city,
      district: g.group_district,
      count: count(g.id)
    })
    |> order_by([g], desc: count(g.id))
    |> Repo.all()
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

  def import_group_with_listings(group_data, listings_data, upserted_at \\ DateTime.utc_now()) do
    Repo.transaction(fn ->
      # Upsert group
      group_attrs = %{
        id: group_data["entity_id"],
        algorithm_version: group_data["algorithm_version"],
        refreshed_at: parse_datetime(group_data["refreshed_at"]),
        inserted_at: parse_datetime(group_data["created_at"]),
        updated_at: parse_datetime(group_data["refreshed_at"]),
        upserted_at: upserted_at
      }

      group_attrs = group_attrs
      |> put_if_present(:group_city, canonical_listing_city(listings_data))
      |> put_if_present(:group_district, canonical_listing_district(listings_data))
      |> put_if_present(:group_zone, canonical_listing_zone(listings_data))
      |> put_if_present(:group_thumbnail, canonical_listing_thumbnail(listings_data))
      |> then(fn attrs ->
        # For group price aggregation, use price_with_vat (the full price buyer pays)
        prices = Enum.map(listings_data, fn l ->
          l["price_with_vat"] || l["price"]
        end) |> Enum.reject(&is_nil/1)
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
          has_active = Enum.any?(listings_data, fn l -> not l["is_delisted"] end)
          a
          |> Map.put(:has_top_floor, has_top)
          |> Map.put(:has_private_seller, has_private)
          |> Map.put(:has_active_listings, has_active)
        end)
      end)

      {:ok, group} = upsert_group(group_attrs)

      # Upsert listings
      Enum.each(listings_data, fn l_attrs ->
        raw_price = l_attrs["price"] && round(l_attrs["price"])
        raw_price_with_vat = l_attrs["price_with_vat"] && round(l_attrs["price_with_vat"])
        vat_included = l_attrs["vat_included"] || false

        listing_map = %{
          id: l_attrs["listing_id"],
          group_id: group_data["entity_id"],
          is_canonical: l_attrs["is_canonical"] || false,
          source_name: l_attrs["source_name"],
          title: l_attrs["title"],
          description: l_attrs["description"],
          price: raw_price,
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
          price_with_vat: raw_price_with_vat,
          vat_included: vat_included,
          upserted_at: upserted_at
        }

        upsert_listing(listing_map)
      end)

      # Upsert similar groups
      Enum.each(group_data["similar_groups"] || [], fn sg ->
        sg_attrs = %{
          source_group_id: group_data["entity_id"],
          similar_group_id: sg["entity_id"],
          similarity_score: sg["similarity_score"],
          match_count: sg["match_count"],
          upserted_at: upserted_at
        }

        case Repo.get_by(SimilarGroup, source_group_id: sg_attrs.source_group_id, similar_group_id: sg_attrs.similar_group_id) do
          nil -> create_similar_group(sg_attrs)
          existing ->
            existing
            |> SimilarGroup.changeset(sg_attrs)
            |> Repo.update()
        end
      end)

      # Recompute earliest_first_seen from actual DB data to ensure accuracy
      earliest = Repo.one(from(l in Listing, where: l.group_id == ^group.id, select: min(l.first_seen_at)))
      if earliest do
        group |> Ecto.Changeset.change(earliest_first_seen: earliest) |> Repo.update!()
      end

      group
    end)
  end

  @doc """
  Deletes all records that were not touched by the current import
  (i.e. upserted_at < import_time). Cleans up stale groups, listings,
  and similar_groups that are no longer present in the export.

  Delete order respects logical dependencies:
  similar_groups → listings → listing_groups
  """
  def cleanup_orphans(import_time) do
    Repo.transaction(fn ->
      {sim_count, _} = Repo.delete_all(from(sg in SimilarGroup, where: sg.upserted_at < ^import_time or is_nil(sg.upserted_at)))
      {listing_count, _} = Repo.delete_all(from(l in Listing, where: l.upserted_at < ^import_time or is_nil(l.upserted_at)))
      {group_count, _} = Repo.delete_all(from(g in ListingGroup, where: g.upserted_at < ^import_time or is_nil(g.upserted_at)))

      %{
        deleted_similar_groups: sim_count,
        deleted_listings: listing_count,
        deleted_groups: group_count
      }
    end)
  end

  # ---- Filter helpers for groups ----

  defp filter_by_active(query, opts) do
    if Keyword.get(opts, :only_active, true) do
      where(query, [g], g.has_active_listings == true)
    else
      query
    end
  end

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

  defp filter_by_min_price(query, opts) do
    case Keyword.get(opts, :min_price) do
      nil -> query
      "" -> query
      min_price -> where(query, [g], g.max_price >= ^min_price)
    end
  end

  defp filter_by_max_price(query, opts) do
    case Keyword.get(opts, :max_price) do
      nil -> query
      "" -> query
      max_price -> where(query, [g], g.min_price <= ^max_price)
    end
  end

  defp filter_by_min_surface(query, opts) do
    case Keyword.get(opts, :min_sqm) do
      nil -> query
      "" -> query
      min_sqm -> where(query, [g], g.max_surface >= ^min_sqm)
    end
  end

  defp filter_by_max_surface(query, opts) do
    case Keyword.get(opts, :max_sqm) do
      nil -> query
      "" -> query
      max_sqm -> where(query, [g], g.min_surface <= ^max_sqm)
    end
  end

  defp filter_by_parking(query, opts) do
    if Keyword.get(opts, :with_parking, false) do
      # Find groups that have at least one listing with parking_price or has_parking feature
      listing_ids =
        Listing
        |> where([l], l.parking_price > 0)
        |> select([l], l.group_id)

      where(query, [g], g.id in subquery(listing_ids))
    else
      query
    end
  end

  defp filter_by_commission(query, opts) do
    if Keyword.get(opts, :with_commission, false) do
      # Find groups that have at least one listing with zero commission.
      # Private sellers (proprietar) never ask for commission, so they are
      # inherently commission-free and should be included.
      listing_ids =
        Listing
        |> where([l], l.agency_commission == 0 or l.is_private_seller == true)
        |> select([l], l.group_id)

      where(query, [g], g.id in subquery(listing_ids))
    else
      query
    end
  end

  defp filter_by_search(query, opts) do
    case Keyword.get(opts, :search) do
      nil -> query
      "" -> query
      term ->
        tsquery = term |> String.trim()
        if tsquery == "" do
          query
        else
          # Full-text search via listing search_vector through subquery
          # Using websearch_to_tsquery for web-like syntax: -term (NOT), "phrase" (exact), OR
          listing_ids =
            Listing
            |> where([l], fragment("search_vector @@ websearch_to_tsquery('romanian', ?)", ^tsquery))
            |> select([l], l.group_id)

          where(query, [g], g.id in subquery(listing_ids))
        end
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
    Enum.map(images, fn
      url when is_binary(url) -> url
      %{"source_url" => url} when is_binary(url) -> url
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
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
