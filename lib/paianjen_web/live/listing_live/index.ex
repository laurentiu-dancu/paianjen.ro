defmodule PaianjenWeb.ListingLive.Index do
  use PaianjenWeb, :live_view

  alias Paianjen.Listings
  alias Paianjen.Listings.GroupPresenter

  @page_size 20
  @default_sort "time_on_market"

  @impl true
  def mount(params, _session, socket) do
    filters = parse_filters_from_params(params)
    {offset, page_number} = resolve_offset(params, filters)
    page = load_page(page_number, offset, filters)

    has_older = filters.cursor != ""

    {:ok,
     assign(socket,
       page_title: "Listări",
       groups: page.groups,
       total_count: page.total_count,
       page: page.page,
       offset: offset,
       total_pages: page.total_pages,
       has_more: page.has_more,
       has_older: has_older,
       cities: page.cities,
       districts: page.districts,
       filters: filters,
       sidebar_open: false,
       loading: false
     )}
  end

  @impl true
  def handle_event("apply_filters", params, socket) do
    filters =
      socket.assigns.filters
      |> merge_filters(params)
      |> Map.merge(%{
        with_parking: params["parking"] == "true",
        with_commission: params["commission"] == "true",
        include_without_images: params["include_without_images"] == "true",
        cursor: ""
      })

    page = load_page(1, 0, filters)

    socket =
      assign(socket,
        filters: filters,
        groups: page.groups,
        total_count: page.total_count,
        page: 1,
        offset: 0,
        total_pages: page.total_pages,
        has_more: page.has_more,
        cities: page.cities,
        districts: page.districts
      )

    {:noreply, push_navigate(socket, to: build_listari_path(filters, 1))}
  end

  @impl true
  def handle_event("filter", params, socket) do
    # LiveView form binding — just update the filter assigns, don't submit yet
    filters = merge_filters(socket.assigns.filters, params)
    {:noreply, assign(socket, filters: filters)}
  end

  @impl true
  def handle_event("toggle_parking", _params, socket) do
    filters = %{socket.assigns.filters | with_parking: !socket.assigns.filters.with_parking}
    {:noreply, assign(socket, filters: filters)}
  end

  @impl true
  def handle_event("toggle_commission", _params, socket) do
    filters = %{socket.assigns.filters | with_commission: !socket.assigns.filters.with_commission}
    {:noreply, assign(socket, filters: filters)}
  end

  @impl true
  def handle_event("toggle_include_without_images", _params, socket) do
    filters = %{socket.assigns.filters | include_without_images: !socket.assigns.filters.include_without_images}
    {:noreply, assign(socket, filters: filters)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    filters = default_filters()
    page = load_page(1, 0, filters)

    socket =
      assign(socket,
        filters: filters,
        groups: page.groups,
        total_count: page.total_count,
        page: 1,
        offset: 0,
        total_pages: page.total_pages,
        has_more: page.has_more,
        cities: page.cities,
        districts: page.districts
      )

    {:noreply, push_navigate(socket, to: ~p"/listari")}
  end

  @impl true
  def handle_event("change_sort", %{"sort_by" => sort_by}, socket) do
    sort_by = if sort_by in sort_values(), do: sort_by, else: @default_sort

    # Apply immediately, keep all filters, reset pagination to the top
    filters = %{socket.assigns.filters | sort_by: sort_by, cursor: ""}
    page = load_page(1, 0, filters)

    socket =
      assign(socket,
        filters: filters,
        groups: page.groups,
        total_count: page.total_count,
        page: 1,
        offset: 0,
        total_pages: page.total_pages,
        has_more: page.has_more,
        has_older: false,
        cities: page.cities,
        districts: page.districts
      )

    {:noreply, push_navigate(socket, to: build_listari_path(filters, 1))}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, sidebar_open: !socket.assigns.sidebar_open)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if socket.assigns.has_more and !socket.assigns.loading do
      socket = assign(socket, loading: true)
      # Continue from the actual loaded offset. Deriving the next offset from
      # `page` is wrong after a cursor-based mount (return from a detail page):
      # the mount loads from the cursor position, which is not necessarily a
      # multiple of page_size, so `(page - 1) * page_size` would overlap and
      # duplicate already-visible groups.
      next_offset = socket.assigns.offset + @page_size
      next_page = socket.assigns.page + 1
      page = load_page(next_page, next_offset, socket.assigns.filters)

      {:noreply,
       assign(socket,
         groups: socket.assigns.groups ++ page.groups,
         page: next_page,
         offset: next_offset,
         has_more: page.has_more,
         loading: false
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("load_previous", _params, socket) do
    if socket.assigns.has_older and !socket.assigns.loading do
      cursor_id = socket.assigns.filters.cursor

      opts = [
        page_size: @page_size,
        city: socket.assigns.filters.city,
        district: socket.assigns.filters.district,
        min_price: parse_int(socket.assigns.filters.min_price),
        max_price: parse_int(socket.assigns.filters.max_price),
        min_sqm: parse_float(socket.assigns.filters.min_sqm),
        max_sqm: parse_float(socket.assigns.filters.max_sqm),
        with_parking: socket.assigns.filters.with_parking,
        with_commission: socket.assigns.filters.with_commission,
        include_without_images: socket.assigns.filters.include_without_images,
        search: socket.assigns.filters.search,
        sort_by: socket.assigns.filters.sort_by
      ]

      {older_groups, has_more} = Listings.list_groups_before_cursor(cursor_id, opts)

      presented =
        older_groups
        |> Enum.map(fn group ->
          listings = group.listings || Listings.list_listings_for_group(group.id)
          GroupPresenter.from_group(group, listings)
        end)

      # New cursor is the last (oldest) group we just loaded, so the page
      # anchor stays stable. If nothing was loaded, keep existing cursor.
      new_cursor =
        case presented do
          [] -> cursor_id
          _ -> List.last(presented).id
        end

      new_filters = %{socket.assigns.filters | cursor: new_cursor}

      {:noreply,
       assign(socket,
         groups: presented ++ socket.assigns.groups,
         filters: new_filters,
         has_older: has_more
       )}
    else
      {:noreply, socket}
    end
  end

  defp default_filters do
    %{
      search: "",
      city: "",
      district: [],
      min_price: "",
      max_price: "",
      min_sqm: "",
      max_sqm: "",
      with_parking: false,
      with_commission: false,
      include_without_images: false,
      cursor: "",
      sort_by: @default_sort
    }
  end

  defp parse_filters_from_params(params) do
    %{
      search: params["search"] || "",
      city: params["city"] || "",
      district: parse_district_param(params["district"]),
      min_price: params["min_price"] || "",
      max_price: params["max_price"] || "",
      min_sqm: params["min_sqm"] || "",
      max_sqm: params["max_sqm"] || "",
      with_parking: params["parking"] == "true",
      with_commission: params["commission"] == "true",
      include_without_images: params["include_without_images"] == "true",
      cursor: params["cursor"] || "",
      sort_by: params["sort_by"] || @default_sort
    }
  end

  defp resolve_offset(params, filters) do
    case params["cursor"] do
      nil ->
        page =
          case params["page"] do
            nil -> 1
            "" -> 1
            page -> String.to_integer(page)
          end

        {(page - 1) * @page_size, page}

      "" ->
        {0, 1}

      cursor_id ->
        opts = [
          page_size: @page_size,
          city: filters.city,
          district: filters.district,
          min_price: parse_int(filters.min_price),
          max_price: parse_int(filters.max_price),
          min_sqm: parse_float(filters.min_sqm),
          max_sqm: parse_float(filters.max_sqm),
          with_parking: filters.with_parking,
          with_commission: filters.with_commission,
          include_without_images: filters.include_without_images,
          search: filters.search,
          sort_by: filters.sort_by
        ]

        Listings.resolve_cursor(cursor_id, opts)
    end
  end

  defp build_listari_path(filters, page) do
    params = []
    params = if filters.search != "", do: [{"search", filters.search} | params], else: params
    params = if filters.city != "", do: [{"city", filters.city} | params], else: params

    params =
      if filters.district != [] do
        Enum.map(filters.district, &{"district[]", &1}) ++ params
      else
        params
      end

    params = if filters.min_price != "", do: [{"min_price", filters.min_price} | params], else: params
    params = if filters.max_price != "", do: [{"max_price", filters.max_price} | params], else: params
    params = if filters.min_sqm != "", do: [{"min_sqm", filters.min_sqm} | params], else: params
    params = if filters.max_sqm != "", do: [{"max_sqm", filters.max_sqm} | params], else: params
    params = if filters.with_parking, do: [{"parking", "true"} | params], else: params
    params = if filters.with_commission, do: [{"commission", "true"} | params], else: params
    params = if filters.include_without_images, do: [{"include_without_images", "true"} | params], else: params
    params = if filters.sort_by != @default_sort, do: [{"sort_by", filters.sort_by} | params], else: params
    params = if filters.cursor != "", do: [{"cursor", filters.cursor} | params], else: params
    params = [{"page", to_string(page)} | params]

    "/listari?#{URI.encode_query(params)}"
  end

  # ---- Data loading ----

  defp load_page(page, offset, filters) do
    opts = [
      page: page,
      page_size: @page_size,
      offset: offset,
      city: filters.city,
      district: filters.district,
      min_price: parse_int(filters.min_price),
      max_price: parse_int(filters.max_price),
      min_sqm: parse_float(filters.min_sqm),
      max_sqm: parse_float(filters.max_sqm),
      with_parking: filters.with_parking,
      with_commission: filters.with_commission,
      include_without_images: filters.include_without_images,
      search: filters.search,
      sort_by: filters.sort_by
    ]

    result = Listings.list_groups_paginated(opts)

    groups =
      result.groups
      |> Enum.map(fn group ->
        listings = group.listings || Listings.list_listings_for_group(group.id)
        GroupPresenter.from_group(group, listings)
      end)

    rows = Listings.list_cities_and_districts()
    cities = rows |> Enum.map(& &1.city) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    districts = rows |> Enum.map(& &1.district) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    %{
      groups: groups,
      total_count: result.total_count,
      page: result.page,
      total_pages: result.total_pages,
      has_more: result.has_more,
      cities: cities,
      districts: districts
    }
  end

  defp merge_filters(current, params) do
    Map.merge(current, %{
      search: params["search"] || "",
      city: params["city"] || "",
      district: parse_district_param(params["district"]),
      min_price: params["min_price"] || "",
      max_price: params["max_price"] || "",
      min_sqm: params["min_sqm"] || "",
      max_sqm: params["max_sqm"] || "",
      cursor: params["cursor"] || ""
    })
  end

  # Sort options for the results header dropdown: {value, label}.
  defp sort_options do
    [
      {"time_on_market", "Cele mai noi primele"},
      {"last_price_drop", "Ultimele reduceri de preț"}
    ]
  end

  defp sort_values, do: Enum.map(sort_options(), &elem(&1, 0))

  # District can arrive as a single string (old links), a list (multiple select
  # or repeated query params), or be absent. Normalize to a list of strings.
  defp parse_district_param(nil), do: []
  defp parse_district_param(""), do: []
  defp parse_district_param(list) when is_list(list), do: Enum.reject(list, &(&1 in [nil, ""]))
  defp parse_district_param(value), do: [value]

  # Human-readable label for the district dropdown summary.
  defp district_summary([]), do: "Toate"
  defp district_summary([district]), do: district
  defp district_summary(districts) when length(districts) <= 2, do: Enum.join(districts, ", ")
  defp district_summary(districts), do: "#{length(districts)} cartiere selectate"

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(n) when is_integer(n), do: n

  defp parse_float(""), do: nil
  defp parse_float(nil), do: nil
  defp parse_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, ""} -> f
      _ -> nil
    end
  end
  defp parse_float(n) when is_float(n), do: n
  defp parse_float(n) when is_integer(n), do: n * 1.0

  defp active_filter_count(filters) do
    [
      filters.search,
      filters.city,
      filters.min_price,
      filters.max_price,
      filters.min_sqm,
      filters.max_sqm
    ]
    |> Enum.count(&(&1 != ""))
    |> Kernel.+(if filters.district != [], do: 1, else: 0)
    |> Kernel.+(if filters.with_parking, do: 1, else: 0)
    |> Kernel.+(if filters.with_commission, do: 1, else: 0)
    |> Kernel.+(if filters.include_without_images, do: 1, else: 0)
  end

  defp format_price(price) when is_float(price) do
    price |> round() |> format_price()
  end

  defp format_price(price) do
    price
    |> to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  defp days_label(0), do: "Astăzi"
  defp days_label(1), do: "o zi pe piață"
  defp days_label(n), do: "#{n} zile pe piață"

  defp drop_label(0, %DateTime{} = dt), do: "Reducere azi la #{format_time(dt)}"
  defp drop_label(0, _), do: "Reducere azi"
  defp drop_label(1, _), do: "Reducere acum o zi"
  defp drop_label(n, _), do: "Reducere acum #{n} zile"

  defp format_time(%DateTime{} = dt) do
    {hour, minute} = Paianjen.Utils.to_bucharest_time(dt)
    "#{pad_zero(hour)}:#{pad_zero(minute)}"
  end

  defp format_time(%NaiveDateTime{} = ndt) do
    {hour, minute} = Paianjen.Utils.to_bucharest_time(ndt)
    "#{pad_zero(hour)}:#{pad_zero(minute)}"
  end

  defp format_time(nil), do: ""

  defp format_date(%DateTime{} = dt) do
    format_date_ro(DateTime.to_date(dt))
  end

  defp format_date(%NaiveDateTime{} = ndt) do
    format_date_ro(ndt)
  end

  defp format_date(_), do: "N/A"

  defp format_date_ro(%Date{} = date) do
    day = date.day
    month = date.month
    year = date.year
    "#{day} #{month_name_ro(month)} #{year}"
  end

  defp format_date_ro(%NaiveDateTime{} = ndt) do
    day = ndt.day
    month = ndt.month
    year = ndt.year
    "#{day} #{month_name_ro(month)} #{year}"
  end

  defp month_name_ro(1), do: "ianuarie"
  defp month_name_ro(2), do: "februarie"
  defp month_name_ro(3), do: "martie"
  defp month_name_ro(4), do: "aprilie"
  defp month_name_ro(5), do: "mai"
  defp month_name_ro(6), do: "iunie"
  defp month_name_ro(7), do: "iulie"
  defp month_name_ro(8), do: "august"
  defp month_name_ro(9), do: "septembrie"
  defp month_name_ro(10), do: "octombrie"
  defp month_name_ro(11), do: "noiembrie"
  defp month_name_ro(12), do: "decembrie"
  defp month_name_ro(_), do: ""

  defp pad_zero(n) when n < 10, do: "0#{n}"
  defp pad_zero(n), do: to_string(n)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">


      <div class="max-w-[1400px] mx-auto px-2 md:px-4 py-3 md:py-6 flex gap-3 md:gap-6">
        <aside class="hidden lg:block w-64 flex-shrink-0">
          <div class="bg-white rounded-2xl border border-slate-100 shadow-sm p-5 sticky top-20 z-10">
            <div class="flex items-center justify-between mb-5">
              <h2 class="text-sm text-slate-800">Filtre</h2>
              <span :if={active_filter_count(@filters) > 0} class="bg-indigo-100 text-indigo-700 text-xs rounded-full px-2 py-0.5">
                <%= active_filter_count(@filters) %> active
              </span>
            </div>
            <.filter_panel filters={@filters} cities={@cities} districts={@districts} />
          </div>
        </aside>

        <div :if={@sidebar_open} class="lg:hidden fixed inset-0 z-30 flex">
          <div class="flex-1 bg-black/30 backdrop-blur-sm" phx-click="toggle_sidebar" />
          <div class="w-72 bg-white shadow-xl p-5 overflow-y-auto">
            <div class="flex items-center justify-between mb-5">
              <h2 class="text-sm text-slate-800">Filtre</h2>
              <button phx-click="toggle_sidebar" class="text-slate-400 hover:text-slate-600">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <.filter_panel filters={@filters} cities={@cities} districts={@districts} />
          </div>
        </div>

        <main class="flex-1 min-w-0">
          <div class="flex items-center justify-between mb-4">
            <p class="text-sm text-slate-600">
              <span class="font-medium text-slate-900"><%= @total_count %></span>
              <%= if @total_count == 1, do: "proprietate", else: "proprietăți" %>
              <span :if={active_filter_count(@filters) > 0} class="text-slate-400 ml-1">
                găsite
              </span>
            </p>
            <form phx-change="change_sort" class="inline-block">
              <select
                name="sort_by"
                aria-label="Sortează după"
                class="text-xs md:text-sm text-slate-600 border border-slate-200 rounded-lg bg-white px-2.5 py-1.5 focus:outline-none focus:ring-2 focus:ring-indigo-400 cursor-pointer"
              >
                <%= for {value, label} <- sort_options() do %>
                  <option value={value} selected={@filters.sort_by == value}><%= label %></option>
                <% end %>
              </select>
            </form>
          </div>

          <div :if={@total_count == 0} class="bg-white rounded-2xl border border-slate-100 shadow-sm p-12 text-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto text-slate-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h3 class="text-lg text-slate-700 mb-2">Nu mai sunt apartamente!</h3>
            <p class="text-sm text-slate-500 max-w-md mx-auto">
              E gata, s-au dat toate. Verifică filtrele.
            </p>
          </div>

          <div :if={@has_older} class="flex justify-center pt-2 pb-4">
            <button
              phx-click="load_previous"
              phx-disable-with="Se încarcă..."
              class="px-6 py-2.5 text-sm text-indigo-600 border border-indigo-200 rounded-lg hover:bg-indigo-50 transition-colors"
            >
              Încarcă mai noi
            </button>
          </div>

          <div
            id="groups-list"
            class="space-y-4"
            phx-hook="InfiniteScroll"
            data-page={@page}
            data-has-more={@has_more}
          >
            <%= for group <- @groups do %>
              <.listing_card group={group} />
            <% end %>
            <div id="scroll-sentinel" class="h-4"></div>
          </div>

          <div :if={@has_more} class="flex justify-center py-8">
            <button
              phx-click="load_more"
              phx-disable-with="Se încarcă..."
              class="px-6 py-2.5 text-sm text-indigo-600 border border-indigo-200 rounded-lg hover:bg-indigo-50 transition-colors"
            >
              Încarcă mai multe
            </button>
          </div>

          <div :if={@total_count > 0 and !@has_more} class="text-center py-8">
            <p class="text-slate-400 text-sm">Toate grupurile au fost încărcate.</p>
          </div>
        </main>
      </div>
    </div>
    """
  end

  defp filter_panel(assigns) do
    ~H"""
    <form phx-submit="apply_filters" class="space-y-6">
      <%!-- Hidden inputs for toggle states so form submission includes them --%>
      <input type="hidden" name="parking" value={"#{@filters.with_parking}"} />
      <input type="hidden" name="commission" value={"#{@filters.with_commission}"} />
      <input type="hidden" name="include_without_images" value={"#{@filters.include_without_images}"} />

      <div>
        <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1.5">Caută</label>
        <div class="relative">
          <svg xmlns="http://www.w3.org/2000/svg" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            name="search"
            value={@filters.search}
            placeholder="Localitate, cartier, titlu..."
            class="w-full pl-9 pr-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white"
          />
        </div>
      </div>

      <div>
        <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1.5">Localitate</label>
        <select name="city" class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white">
          <option value="">Toate</option>
          <%= for city <- @cities do %>
            <option value={city} selected={@filters.city == city}><%= city %></option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1.5">Cartier</label>
        <details class="district-dropdown relative">
          <summary class="flex items-center justify-between gap-2 w-full px-3 py-2 border border-slate-200 rounded-lg bg-white cursor-pointer select-none list-none focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400">
            <span class="truncate text-sm text-slate-700">
              <%= district_summary(@filters.district) %>
            </span>
            <svg xmlns="http://www.w3.org/2000/svg" class="district-chevron w-4 h-4 text-slate-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          </summary>
          <div class="district-panel absolute left-0 right-0 top-full z-20 mt-1 max-h-60 overflow-y-auto overscroll-contain border border-slate-200 rounded-lg bg-white shadow-lg">
            <%= for district <- @districts do %>
              <label class="district-option flex items-center gap-3 px-3 py-2.5 min-h-[44px] cursor-pointer hover:bg-slate-50">
                <input
                  type="checkbox"
                  name="district[]"
                  value={district}
                  checked={district in @filters.district}
                  class="accent-indigo-600 shrink-0"
                />
                <span class="text-sm text-slate-700 truncate"><%= district %></span>
              </label>
            <% end %>
          </div>
        </details>
      </div>

      <div>
        <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1.5">Preț (€)</label>
        <div class="flex gap-2">
          <input type="number" name="min_price" value={@filters.min_price} placeholder="Min" class="w-1/2 px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white" />
          <input type="number" name="max_price" value={@filters.max_price} placeholder="Max" class="w-1/2 px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white" />
        </div>
      </div>

      <div>
        <label class="block text-xs uppercase tracking-wide text-slate-400 mb-1.5">Suprafață (m²)</label>
        <div class="flex gap-2">
          <input type="number" name="min_sqm" value={@filters.min_sqm} placeholder="Min" class="w-1/2 px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white" />
          <input type="number" name="max_sqm" value={@filters.max_sqm} placeholder="Max" class="w-1/2 px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white" />
        </div>
      </div>

      <div class="space-y-3">
        <label class="flex items-center gap-3 cursor-pointer group">
          <button type="button" phx-click="toggle_parking" class={"w-10 h-5 rounded-full transition-colors flex-shrink-0 relative #{if @filters.with_parking, do: "bg-indigo-500", else: "bg-slate-200"}"}>
            <span class={"absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform #{if @filters.with_parking, do: "translate-x-5", else: "translate-x-0"}"} />
          </button>
          <div class="flex items-center gap-1.5 text-sm text-slate-700 group-hover:text-slate-900">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8 7h8m-8 4h8m-4 4v4m-4-4h8a2 2 0 002-2V5a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
            Cu parcare
          </div>
        </label>

        <label class="flex items-center gap-3 cursor-pointer group">
          <button type="button" phx-click="toggle_commission" class={"w-10 h-5 rounded-full transition-colors flex-shrink-0 relative #{if @filters.with_commission, do: "bg-indigo-500", else: "bg-slate-200"}"}>
            <span class={"absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform #{if @filters.with_commission, do: "translate-x-5", else: "translate-x-0"}"} />
          </button>
          <div class="flex items-center gap-1.5 text-sm text-slate-700 group-hover:text-slate-900">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Comision 0
          </div>
        </label>

        <label class="flex items-center gap-3 cursor-pointer group">
          <button type="button" phx-click="toggle_include_without_images" class={"w-10 h-5 rounded-full transition-colors flex-shrink-0 relative #{if @filters.include_without_images, do: "bg-indigo-500", else: "bg-slate-200"}"}>
            <span class={"absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform #{if @filters.include_without_images, do: "translate-x-5", else: "translate-x-0"}"} />
          </button>
          <div class="flex items-center gap-1.5 text-sm text-slate-700 group-hover:text-slate-900">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            Include fără imagini
          </div>
        </label>
      </div>

      <button
        type="submit"
        class="w-full flex items-center justify-center gap-1.5 py-2.5 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 transition-colors"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
        </svg>
        Filtrează
      </button>

      <button
        :if={active_filter_count(@filters) > 0}
        type="button"
        phx-click="reset_filters"
        class="w-full flex items-center justify-center gap-1.5 py-2 text-sm text-slate-500 hover:text-red-500 border border-slate-200 rounded-lg hover:border-red-200 transition-colors"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
        Șterge filtrele (<%= active_filter_count(@filters) %>)
      </button>
    </form>
    """
  end

  defp listing_card(assigns) do
    ~H"""
    <a
      href={~p"/listari/#{@group.id}"}
      data-listing-card
      data-group-id={@group.id}
      class="bg-white border border-slate-100 rounded-2xl shadow-sm hover:shadow-md hover:border-indigo-100 transition-all cursor-pointer overflow-hidden relative block max-h-56 md:max-h-none"
    >
      <.spider_web days_on_market={@group.days_on_market} />

      <div class="flex gap-0">
        <div class="w-32 md:w-44 flex-shrink-0 relative aspect-[4/3]">
          <%= if @group.image_url do %>
            <.image_with_fallback src={@group.image_url} alt={"Apartament #{@group.district || @group.city}"} class="absolute inset-0 w-full h-full" />
          <% else %>
            <.no_image_placeholder class="absolute inset-0 w-full h-full" />
          <% end %>
        </div>

        <div class="flex-1 p-2.5 md:p-5 min-w-0">
          <div class="flex items-center gap-1.5 text-slate-400 text-xs mb-1 md:mb-1.5">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <span class="truncate">
              <%= @group.city %><%= if @group.district, do: " · #{@group.district}" %><%= if @group.zone, do: " · #{@group.zone}" %>
            </span>
          </div>

          <%
            active_listings = Enum.reject(@group.listings, & &1[:delisted_date])
            representative_title = case active_listings do
              [first | _] -> first[:title]
              [] -> case @group.listings do
                [first | _] -> first[:title]
                [] -> ""
              end
            end
          %>
          <p class="text-slate-800 text-xs md:text-sm leading-snug mb-1.5 md:mb-2 pr-2 truncate"><%= representative_title %></p>

          <%
            has_vat_included = Enum.any?(@group.listings, fn l -> l.vat_included end)
          %>
          <div class="flex flex-wrap items-end gap-x-2 md:gap-x-6 gap-y-1 md:gap-y-2 mb-1.5 md:mb-4">
            <div>
              <div class="flex items-baseline gap-1.5 md:gap-2 flex-wrap">
                <span class="text-lg md:text-2xl text-slate-900">
                <%= if @group.min_price && @group.max_price && @group.min_price == @group.max_price, do: format_price(@group.min_price) <> " €", else: "de la " <> format_price(@group.min_price) <> " €" %>
              </span>
                <%= if has_vat_included do %>
                  <span class="px-1.5 py-0.5 bg-blue-50 text-blue-700 text-xs rounded-full border border-blue-100">cu TVA</span>
                <% end %>
                <span class="text-xs text-slate-400">
                  <%= if @group.min_price && @group.min_surface, do: format_price(@group.min_price / @group.min_surface) <> " €/m²", else: "" %>
                </span>
                <%
                  has_private = Enum.any?(active_listings, & &1[:is_private])
                  has_zero_commission = Enum.any?(active_listings, & &1[:agency_commission] == 0)
                  show_commission = !has_zero_commission && !has_private && length(active_listings) > 0
                %>
                <%= if has_private && !show_commission do %>
                  <span class="px-1.5 py-0.5 bg-emerald-50 text-emerald-700 text-xs rounded-full border border-emerald-100">proprietar</span>
                <% end %>
                <%= if has_zero_commission && !show_commission do %>
                  <span class="px-1.5 py-0.5 bg-blue-50 text-blue-700 text-xs rounded-full border border-blue-100">comision 0</span>
                <% end %>
                <%= if show_commission do %>
                  <% min_comm = Enum.map(active_listings, & &1[:agency_commission]) |> Enum.min(fn -> nil end) %>
                  <%= if min_comm && min_comm > 0 do %>
                    <span class="px-1.5 py-0.5 bg-orange-50 text-orange-700 text-xs rounded-full border border-orange-100">comision <%= format_price(min_comm) %> €</span>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-x-2.5 md:gap-x-4 gap-y-1 text-xs text-slate-500 mb-1.5 md:mb-4">
            <%= if @group.min_surface do %>
              <span class="flex items-center gap-0.5">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" /></svg>
                <%= if @group.max_surface && @group.min_surface == @group.max_surface, do: "#{round(@group.min_surface)}", else: "#{round(@group.min_surface)}–#{round(@group.max_surface)}" %> m²
              </span>
            <% end %>
            <%= if @group.rooms do %>
              <span class="flex items-center gap-0.5">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
                <%= @group.rooms %> camere
              </span>
            <% end %>
            <%= if @group.floor do %>
              <span class="flex items-center gap-0.5">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                Et. <%= if @group.total_floors, do: "#{@group.floor}/#{@group.total_floors}", else: "#{@group.floor}" %>
              </span>
            <% end %>
            <%= if @group.parking_price do %>
              <span class="flex items-center gap-0.5">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7h8m-8 4h8m-4 4v4m-4-4h8a2 2 0 002-2V5a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                Parcare <%= format_price(@group.parking_price) %> €
              </span>
            <% end %>
            <%= if @group.year_built do %>
              <span>An <%= @group.year_built %></span>
            <% end %>
          </div>

          <div class="flex items-center justify-between pt-2 md:pt-3 border-t border-slate-50">
            <div class="flex flex-wrap items-center gap-1.5 text-xs text-slate-500">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <%= if @group.days_on_market == 0 and @group.first_seen_at do %>
                Astăzi la <%= format_time(@group.first_seen_at) %>
              <% else %>
                <%= days_label(@group.days_on_market) %>
              <% end %>

              <%= if @group.last_price_drop_at do %>
                <span class="flex items-center gap-1 text-emerald-600" title="Ultima reducere de preț">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 17l6-6 4 4 8-8m0 0h-5m5 0v5" />
                  </svg>
                  <%= drop_label(@group.days_since_last_price_drop, @group.last_price_drop_at) %>
                </span>
              <% end %>
            </div>

            <%
              health_ratio = if @group.total_listings > 0, do: @group.active_listings / @group.total_listings, else: 0
              health_color = cond do
                health_ratio >= 0.75 -> "text-emerald-600 bg-emerald-50 border-emerald-100"
                health_ratio >= 0.5 -> "text-amber-600 bg-amber-50 border-amber-100"
                true -> "text-orange-600 bg-orange-50 border-orange-100"
              end
            %>
            <div class={"flex items-center gap-1 px-1.5 py-0.5 md:px-2.5 md:py-1 rounded-full border text-xs #{health_color}"}>
              <svg xmlns="http://www.w3.org/2000/svg" class="w-2.5 h-2.5 md:w-3 md:h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <%= @group.active_listings %>/<%= @group.total_listings %>
            </div>
          </div>
        </div>
      </div>
    </a>
    """
  end

  defp spider_web(assigns) do
    ~H"""
    <%= if @days_on_market >= 30 do %>
      <% opacity = min(0.15 + ((@days_on_market - 30) / 60) * 0.3, 0.45) %>
      <svg class="absolute top-0 right-0 w-24 h-24 pointer-events-none" viewBox="0 0 100 100" style={"opacity: #{opacity}"}>
        <g stroke="#4F46E5" stroke-width="0.5" fill="none">
          <line x1="90" y1="10" x2="50" y2="50" />
          <line x1="95" y1="25" x2="50" y2="50" />
          <line x1="98" y1="40" x2="50" y2="50" />
          <line x1="98" y1="55" x2="50" y2="50" />
          <line x1="95" y1="70" x2="50" y2="50" />
          <line x1="75" y1="5" x2="50" y2="50" />
          <circle cx="50" cy="50" r="8" />
          <circle cx="50" cy="50" r="18" />
          <circle cx="50" cy="50" r="28" />
          <circle cx="50" cy="50" r="38" />
          <circle cx="50" cy="50" r="48" />
        </g>
        <%= if @days_on_market > 60 do %>
          <g fill="#4F46E5" opacity="0.6">
            <ellipse cx="92" cy="15" rx="3" ry="2.5" />
            <circle cx="92" cy="15" r="1.5" />
          </g>
        <% end %>
      </svg>
    <% end %>
    """
  end
end
