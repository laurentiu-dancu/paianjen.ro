defmodule Paianjen.Listings do
  @moduledoc """
  The Listings context — manages listing groups, individual listings, and similar groups.
  """
  import Ecto.Query, warn: false
  alias Paianjen.Repo
  alias Paianjen.Listings.Listing
  alias Paianjen.Listings.ListingGroup
  alias Paianjen.Listings.SimilarGroup
  alias Paianjen.Listings.Wishlist
  alias Paianjen.Listings.WishlistItem

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
    |> filter_by_images(opts)
    |> filter_by_search(opts)
    |> filter_by_sort(opts)
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
      |> filter_by_images(opts)
      |> filter_by_search(opts)
      |> filter_by_sort(opts)

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
          |> filter_by_images(opts)
          |> filter_by_search(opts)
          |> filter_by_sort(opts)

        # Count how many groups come before this one in the active sort order
        position =
          base_query
          |> groups_before_cursor(group, opts)
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
          |> filter_by_images(opts)
          |> filter_by_search(opts)
          |> filter_by_sort(opts)

        # Groups that come BEFORE the cursor in the active sort order (newer items).
        # "Before" = ordered ahead of the cursor by the sort keys.
        newer_query =
          base_query
          |> groups_before_cursor(group, opts)
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

  # ---- Wishlists (colectii) ----

  # Upper bound on saved groups per wishlist, to keep DB growth bounded.
  @max_wishlist_items 200

  @doc """
  Creates a wishlist row for `wishlist_id` (idempotent — `on_conflict: :nothing`).
  """
  def create_wishlist(wishlist_id \\ Ecto.UUID.generate()) do
    %Wishlist{}
    |> Wishlist.changeset(%{id: wishlist_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc "Returns true when a wishlist with the given id exists."
  def wishlist_exists?(wishlist_id) do
    Repo.exists?(from w in Wishlist, where: w.id == ^wishlist_id)
  end

  @doc """
  Adds or removes `group_id` from the wishlist (idempotent toggle).

  The wishlist is always identified by the caller (the session), never by the
  client. Returns `{:ok, :added}` / `{:ok, :removed}`,
  `{:error, :wishlist_full}` when at the size cap, or `{:error, :not_found}`
  when the wishlist row does not exist.
  """
  def toggle_wishlist_item(wishlist_id, group_id) do
    if not wishlist_exists?(wishlist_id) do
      {:error, :not_found}
    else
      case Repo.get_by(WishlistItem, wishlist_id: wishlist_id, group_id: group_id) do
        nil ->
          item_count =
            Repo.aggregate(
              from(wi in WishlistItem, where: wi.wishlist_id == ^wishlist_id),
              :count,
              :group_id
            )

          if item_count >= @max_wishlist_items do
            {:error, :wishlist_full}
          else
            %WishlistItem{}
            |> WishlistItem.changeset(%{
              wishlist_id: wishlist_id,
              group_id: group_id,
              added_at: DateTime.utc_now()
            })
            |> Repo.insert(on_conflict: :nothing)
            |> case do
              {:ok, _item} -> {:ok, :added}
              {:error, _changeset} -> {:error, :not_found}
            end
          end

        item ->
          {:ok, _} = Repo.delete(item)
          {:ok, :removed}
      end
    end
  end

  @doc "Returns the group_ids currently saved in the wishlist."
  def wishlist_group_ids(wishlist_id) do
    WishlistItem
    |> where([wi], wi.wishlist_id == ^wishlist_id)
    |> select([wi], wi.group_id)
    |> Repo.all()
  end

  @doc """
  Returns the wishlist's entries (newest `added_at` first) with their group
  preloaded, as `%{group: ListingGroup, added_at: DateTime}` maps.

  Groups that no longer exist (deleted by the import pipeline's
  `cleanup_orphans`) are skipped via the inner join, so the read path never
  crashes on a stale reference.
  """
  def list_wishlist_entries(wishlist_id) do
    query =
      from(wi in WishlistItem,
        where: wi.wishlist_id == ^wishlist_id,
        join: g in ListingGroup,
        on: g.id == wi.group_id,
        order_by: [desc: wi.added_at, asc: g.id],
        select: %{group: g, added_at: wi.added_at}
      )

    query
    |> Repo.all()
    |> then(fn entries ->
      # Preload listings on the group structs directly (Repo.preload on a list
      # of plain maps is not supported), then put them back in the entries.
      groups = Repo.preload(Enum.map(entries, & &1.group), :listings)

      entries
      |> Enum.zip(groups)
      |> Enum.map(fn {entry, group} -> %{entry | group: group} end)
    end)
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
        # NOTE: Enum.min/2 on DateTime structs is NOT chronological — structs
        # are compared structurally (key order), so "day" is compared before
        # "year" and the wrong date can win. Compare by epoch seconds instead.
        |> put_if_present(:earliest_first_seen, Enum.min_by(first_seens, &DateTime.to_unix/1, fn -> nil end))
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

      # Price history + last price drop come pre-computed from the export.
      # A group whose price never dropped has no real last_price_drop_at; we
      # fall back to earliest_first_seen (the listing creation date) so every
      # group still gets a sortable value in the "time since last price drop"
      # order. We deliberately use the creation date, NOT the first snapshot's
      # scraped_at: old listings that predate little-spider's scraping would
      # otherwise look freshly "dropped" and wrongly interleave near the top.
      last_drop =
        parse_datetime(group_data["last_price_drop_at"]) ||
          group_attrs[:earliest_first_seen]

      group_attrs =
        group_attrs
        |> put_if_present(:price_history, group_data["group_price_history"] || [])
        |> put_if_present(:last_price_drop_at, last_drop)

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
          price_history: l_attrs["price_history"] || [],
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
      [] -> query
      districts when is_list(districts) ->
        districts = Enum.reject(districts, &(&1 in [nil, ""]))

        if districts == [] do
          query
        else
          where(query, [g], g.group_district in ^districts)
        end

      district ->
        where(query, [g], g.group_district == ^district)
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

  defp filter_by_images(query, opts) do
    if Keyword.get(opts, :include_without_images, false) do
      query
    else
      # Only groups where at least one listing has a thumbnail
      listing_ids =
        Listing
        |> where([l], not is_nil(l.thumbnail) and l.thumbnail != "")
        |> select([l], l.group_id)

      where(query, [g], g.id in subquery(listing_ids))
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

  defp filter_by_sort(query, opts) do
    case Keyword.get(opts, :sort_by) do
      "last_price_drop" ->
        # Most recent price drop first; groups that never dropped (NULL) sort last.
        # Callers append the tiebreakers (earliest_first_seen DESC, id ASC) via
        # their own order_by, which Ecto combines into a single ORDER BY.
        from g in query, order_by: [desc_nulls_last: g.last_price_drop_at]

      _ ->
        query
    end
  end

  # Groups that come BEFORE the cursor group in the given sort order (i.e. the
  # "newer" items that should appear first). Default sort: earliest_first_seen
  # DESC, id ASC. last_price_drop sort: last_price_drop_at DESC NULLS LAST, then
  # the same tiebreakers.
  #
  # The cursor's NULL-ness is resolved in Elixir so we never emit a bare
  # `is_nil(^param)` comparison, which Postgres can't type (indeterminate
  # datatype) when the param is used only inside IS NULL.
  defp groups_before_cursor(query, group, opts) do
    case Keyword.get(opts, :sort_by) do
      "last_price_drop" ->
        # NOTE: these branches must express the OR *inside* a single `where`,
        # not as `where(...) |> or_where(...)`. Ecto's `or_where` groups with
        # ALL preceding wheres, generating `(base_filters AND A) OR B`, which
        # lets the second branch escape the active/images filters and overcount.
        if is_nil(group.last_price_drop_at) do
          # Cursor has NULL last_price_drop_at (sorts last under NULLS LAST):
          # every group with a real drop sorts before it, plus NULL-drop groups
          # that tiebreak ahead of it.
          where(query, [g],
            not is_nil(g.last_price_drop_at) or
              (is_nil(g.last_price_drop_at) and
                 (g.earliest_first_seen > ^group.earliest_first_seen or
                    (g.earliest_first_seen == ^group.earliest_first_seen and g.id < ^group.id)))
          )
        else
          # Cursor has a real drop: a greater drop date sorts before it, or an
          # equal drop date that tiebreaks ahead.
          where(query, [g],
            g.last_price_drop_at > ^group.last_price_drop_at or
              (g.last_price_drop_at == ^group.last_price_drop_at and
                 (g.earliest_first_seen > ^group.earliest_first_seen or
                    (g.earliest_first_seen == ^group.earliest_first_seen and g.id < ^group.id)))
          )
        end

      _ ->
        where(
          query,
          [g],
          g.earliest_first_seen > ^group.earliest_first_seen or
            (g.earliest_first_seen == ^group.earliest_first_seen and g.id < ^group.id)
        )
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
