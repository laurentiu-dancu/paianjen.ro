defmodule PaianjenWeb.ListingLive.Index do
  use PaianjenWeb, :live_view

  alias Paianjen.Listings
  alias Paianjen.Listings.GroupPresenter

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    page = load_page(1, default_filters())

    {:ok,
     assign(socket,
       page_title: "Listări",
       groups: page.groups,
       total_count: page.total_count,
       page: page.page,
       total_pages: page.total_pages,
       has_more: page.has_more,
       cities: page.cities,
       districts: page.districts,
       filters: default_filters(),
       sidebar_open: false,
       loading: false
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = merge_filters(socket.assigns.filters, params)
    page = load_page(1, filters)

    {:noreply,
     assign(socket,
       filters: filters,
       groups: page.groups,
       total_count: page.total_count,
       page: 1,
       total_pages: page.total_pages,
       has_more: page.has_more,
       cities: page.cities,
       districts: page.districts
     )}
  end

  @impl true
  def handle_event("toggle_parking", _params, socket) do
    filters = %{socket.assigns.filters | with_parking: !socket.assigns.filters.with_parking}
    page = load_page(1, filters)

    {:noreply,
     assign(socket,
       filters: filters,
       groups: page.groups,
       total_count: page.total_count,
       page: 1,
       total_pages: page.total_pages,
       has_more: page.has_more
     )}
  end

  @impl true
  def handle_event("toggle_commission", _params, socket) do
    filters = %{socket.assigns.filters | with_commission: !socket.assigns.filters.with_commission}
    page = load_page(1, filters)

    {:noreply,
     assign(socket,
       filters: filters,
       groups: page.groups,
       total_count: page.total_count,
       page: 1,
       total_pages: page.total_pages,
       has_more: page.has_more
     )}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    filters = default_filters()
    page = load_page(1, filters)

    {:noreply,
     assign(socket,
       filters: filters,
       groups: page.groups,
       total_count: page.total_count,
       page: 1,
       total_pages: page.total_pages,
       has_more: page.has_more,
       cities: page.cities,
       districts: page.districts
     )}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, sidebar_open: !socket.assigns.sidebar_open)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if socket.assigns.has_more and !socket.assigns.loading do
      next_page = socket.assigns.page + 1
      page = load_page(next_page, socket.assigns.filters)

      {:noreply,
       assign(socket,
         groups: socket.assigns.groups ++ page.groups,
         page: next_page,
         has_more: page.has_more,
         loading: false
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("logout", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  defp default_filters do
    %{
      search: "",
      city: "",
      district: "",
      min_price: "",
      max_price: "",
      min_sqm: "",
      max_sqm: "",
      with_parking: false,
      with_commission: false
    }
  end

  # ---- Data loading ----

  defp load_page(page, filters) do
    opts = [
      page: page,
      page_size: @page_size,
      city: filters.city,
      district: filters.district,
      min_price: parse_int(filters.min_price),
      max_price: parse_int(filters.max_price),
      min_sqm: parse_float(filters.min_sqm),
      max_sqm: parse_float(filters.max_sqm),
      with_parking: filters.with_parking,
      with_commission: filters.with_commission,
      search: filters.search
    ]

    result = Listings.list_groups_paginated(opts)

    groups =
      result.groups
      |> Enum.map(fn group ->
        listings = group.listings || Listings.list_listings_for_group(group.id)
        GroupPresenter.from_group(group, listings)
      end)

    {cities, districts} =
      if page == 1 do
        all_opts = opts ++ [page: 1, page_size: 1000]
        case Listings.list_groups_paginated(all_opts) do
          %{groups: all_g} ->
            all_g =
              all_g
              |> Enum.map(fn g ->
                listings = g.listings || Listings.list_listings_for_group(g.id)
                GroupPresenter.from_group(g, listings)
              end)
            {
              all_g |> Enum.map(& &1.city) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort(),
              all_g |> Enum.map(& &1.district) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()
            }
          _ ->
            {extract_distinct(groups, & &1.city), extract_distinct(groups, & &1.district)}
        end
      else
        {extract_distinct(groups, & &1.city), extract_distinct(groups, & &1.district)}
      end

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

  defp extract_distinct(groups, field_fn) do
    groups
    |> Enum.map(field_fn)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp merge_filters(current, params) do
    Map.merge(current, %{
      search: params["search"] || "",
      city: params["city"] || "",
      district: params["district"] || "",
      min_price: params["min_price"] || "",
      max_price: params["max_price"] || "",
      min_sqm: params["min_sqm"] || "",
      max_sqm: params["max_sqm"] || ""
    })
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(n) when is_integer(n), do: n

  defp parse_float(""), do: nil
  defp parse_float(nil), do: nil
  defp parse_float(s) when is_binary(s), do: String.to_float(s)
  defp parse_float(n) when is_float(n), do: n

  defp active_filter_count(filters) do
    [
      filters.search,
      filters.city,
      filters.district,
      filters.min_price,
      filters.max_price,
      filters.min_sqm,
      filters.max_sqm
    ]
    |> Enum.count(&(&1 != ""))
    |> Kernel.+(if filters.with_parking, do: 1, else: 0)
    |> Kernel.+(if filters.with_commission, do: 1, else: 0)
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
  defp days_label(1), do: "1 zi pe piață"
  defp days_label(n), do: "#{n} zile pe piață"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">
      <%!-- Mobile filter toggle + logout --%>
      <div class="lg:hidden flex items-center justify-end gap-3 px-4 py-3 bg-white border-b border-slate-100">
        <button
          phx-click="toggle_sidebar"
          class="flex items-center gap-1.5 px-3 py-1.5 text-sm text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
          </svg>
          Filtre
          <span :if={active_filter_count(@filters) > 0} class="bg-indigo-500 text-white text-xs rounded-full px-1.5 py-0.5 leading-none">
            <%= active_filter_count(@filters) %>
          </span>
        </button>

        <button
          phx-click="logout"
          class="flex items-center gap-1.5 px-3 py-1.5 text-sm text-slate-500 hover:text-slate-800 hover:bg-slate-100 rounded-lg transition-colors"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
          </svg>
          Ieși
        </button>
      </div>

      <div class="max-w-[1400px] mx-auto px-4 py-6 flex gap-6">
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
              <%= if @total_count == 1, do: "grup", else: "grupuri" %>
              <span :if={active_filter_count(@filters) > 0} class="text-slate-400 ml-1">
                găsite
              </span>
            </p>
            <p class="text-xs text-slate-400">cele mai noi primele</p>
          </div>

          <div :if={@total_count == 0} class="bg-white rounded-2xl border border-slate-100 shadow-sm p-12 text-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto text-slate-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h3 class="text-lg text-slate-700 mb-2">Nu există date importate</h3>
            <p class="text-sm text-slate-500 max-w-md mx-auto">
              Importați date din little-spider rulând:
              <code class="block mt-2 bg-slate-100 rounded px-3 py-2 text-xs">mix run priv/repo/import_from_export.exs</code>
            </p>
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
    <form phx-change="filter" class="space-y-6">
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
        <select name="district" class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white">
          <option value="">Toate</option>
          <%= for district <- @districts do %>
            <option value={district} selected={@filters.district == district}><%= district %></option>
          <% end %>
        </select>
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
            Doar cu comision
          </div>
        </label>
      </div>

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
    <.link
      navigate={~p"/listari/#{@group.id}"}
      class="bg-white border border-slate-100 rounded-2xl shadow-sm hover:shadow-md hover:border-indigo-100 transition-all cursor-pointer overflow-hidden relative block"
    >
      <.spider_web days_on_market={@group.days_on_market} />

      <div class="flex gap-0">
        <div :if={@group.image_url} class="hidden sm:block w-44 flex-shrink-0 relative overflow-hidden">
          <img src={@group.image_url} alt={"Apartament #{@group.district || @group.city}"} class="absolute inset-0 w-full h-full object-cover" />
        </div>

        <div class="flex-1 p-5 min-w-0">
          <div class="flex items-center gap-1.5 text-slate-400 text-xs mb-1.5">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <span>
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
          <p class="text-slate-800 text-sm leading-snug mb-3 pr-2 line-clamp-2"><%= representative_title %></p>

          <div class="flex flex-wrap items-end gap-x-6 gap-y-2 mb-4">
            <div>
              <div class="flex items-baseline gap-2 flex-wrap">
                <span class="text-2xl text-slate-900"><%= format_price(@group.average_price) %> €</span>
                <%
                  has_private = Enum.any?(active_listings, & &1[:is_private])
                  has_zero_commission = Enum.any?(active_listings, & &1[:agency_commission] == 0)
                  show_commission = !has_zero_commission && !has_private && length(active_listings) > 0
                %>
                <%= if has_private && !show_commission do %>
                  <span class="px-2 py-0.5 bg-emerald-50 text-emerald-700 text-xs rounded-full border border-emerald-100">proprietar</span>
                <% end %>
                <%= if has_zero_commission && !show_commission do %>
                  <span class="px-2 py-0.5 bg-blue-50 text-blue-700 text-xs rounded-full border border-blue-100">comision 0</span>
                <% end %>
              </div>
              <p class="text-xs text-slate-400 mt-0.5"><%= format_price(@group.price_per_sqm) %> €/m²</p>
            </div>

            <%= if @group.parking_price do %>
              <div class="flex items-center gap-1.5">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M8 7h8m-8 4h8m-4 4v4m-4-4h8a2 2 0 002-2V5a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
                <span class="text-sm text-slate-700">Parcare <span class="text-slate-900"><%= format_price(@group.parking_price) %> €</span></span>
              </div>
            <% end %>
          </div>

          <div class="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-slate-500 mb-4">
            <span class="flex items-center gap-1">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
              </svg>
              <%= @group.surface_area && round(@group.surface_area) %> m²
            </span>

            <%= if @group.floor && @group.total_floors do %>
              <span class="flex items-center gap-1">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
                Et. <%= @group.floor %>/<%= @group.total_floors %>
              </span>
            <% end %>

            <%= if @group.year_built do %>
              <span>An <%= @group.year_built %></span>
            <% end %>

            <% show_comm = !Enum.any?(active_listings, &(&1[:agency_commission] == 0)) && !Enum.any?(active_listings, & &1[:is_private]) && length(active_listings) > 0 %>
            <%= if show_comm do %>
              <% avg_comm = Enum.sum(Enum.map(active_listings, & &1[:agency_commission])) / length(active_listings) %>
              <span class="flex items-center gap-1 text-slate-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Comision mediu <%= format_price(avg_comm) %> €
              </span>
            <% end %>
          </div>

          <div class="flex items-center justify-between pt-3 border-t border-slate-50">
            <div class="flex items-center gap-1.5 text-xs text-slate-500">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <%= days_label(@group.days_on_market) %>
            </div>

            <%
              health_ratio = if @group.total_listings > 0, do: @group.active_listings / @group.total_listings, else: 0
              health_color = cond do
                health_ratio >= 0.75 -> "text-emerald-600 bg-emerald-50 border-emerald-100"
                health_ratio >= 0.5 -> "text-amber-600 bg-amber-50 border-amber-100"
                true -> "text-orange-600 bg-orange-50 border-orange-100"
              end
            %>
            <div class={"flex items-center gap-1 px-2.5 py-1 rounded-full border text-xs #{health_color}"}>
              <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <%= @group.active_listings %>/<%= @group.total_listings %> active
            </div>
          </div>
        </div>
      </div>
    </.link>
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
