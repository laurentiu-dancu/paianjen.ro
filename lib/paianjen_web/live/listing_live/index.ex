defmodule PaianjenWeb.ListingLive.Index do
  use PaianjenWeb, :live_view

  alias Paianjen.Listings
  alias Paianjen.Listings.GroupPresenter

  @impl true
  def mount(_params, _session, socket) do
    groups = load_groups()
    cities = load_cities(groups)
    districts = load_districts(groups)

    {:ok,
     assign(socket,
       page_title: "Listări",
       groups: groups,
       cities: cities,
       districts: districts,
       filters: default_filters(),
       sidebar_open: false
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters =
      socket.assigns.filters
      |> Map.merge(%{
        search: params["search"] || "",
        city: params["city"] || "",
        district: params["district"] || "",
        min_price: params["min_price"] || "",
        max_price: params["max_price"] || "",
        min_sqm: params["min_sqm"] || "",
        max_sqm: params["max_sqm"] || ""
      })

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
  def handle_event("reset_filters", _params, socket) do
    {:noreply, assign(socket, filters: default_filters())}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, sidebar_open: !socket.assigns.sidebar_open)}
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

  defp filtered_groups(groups, filters) do
    groups
    |> Enum.filter(fn group ->
      term = String.downcase(filters.search)

      search_match =
        term == "" or
          (group.city && String.downcase(group.city) =~ term) or
          (group.district && String.downcase(group.district) =~ term) or
          (group.zone && String.downcase(group.zone) =~ term) or
          Enum.any?(group.listings, fn l -> l[:title] && String.downcase(l[:title]) =~ term end)

      city_match = filters.city == "" || group.city == filters.city
      district_match = filters.district == "" || group.district == filters.district

      min_price_match =
        filters.min_price == "" or
          group.average_price >= String.to_integer(filters.min_price)

      max_price_match =
        filters.max_price == "" or
          group.average_price <= String.to_integer(filters.max_price)

      min_sqm_match =
        filters.min_sqm == "" or
          (group.surface_area && group.surface_area >= String.to_float(filters.min_sqm))

      max_sqm_match =
        filters.max_sqm == "" or
          (group.surface_area && group.surface_area <= String.to_float(filters.max_sqm))

      parking_match = !filters.with_parking || !is_nil(group.parking_price)

      commission_match =
        !filters.with_commission or
          Enum.all?(Enum.reject(group.listings, & &1[:delisted_date]), fn l ->
            Map.get(l, :agency_commission, 0) > 0
          end)

      search_match and city_match and district_match and min_price_match and max_price_match and
        min_sqm_match and max_sqm_match and parking_match and commission_match
    end)
  end

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

  # ---- Data loading ----

  defp load_groups do
    case Listings.list_groups() do
      [] ->
        []

      groups ->
        groups
        |> Enum.map(fn group ->
          listings = group.listings || Listings.list_listings_for_group(group.id)
          GroupPresenter.from_group(group, listings)
        end)
        |> Enum.sort_by(& &1.days_on_market, :asc)
    end
  end

  defp load_cities(groups) do
    groups
    |> Enum.map(& &1.city)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp load_districts(groups) do
    groups
    |> Enum.map(& &1.district)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

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
            <p class="text-sm text-slate-500">
              <%= length(filtered_groups(@groups, @filters)) %> grupuri găsite
            </p>
          </div>

          <div :if={@groups == []} class="bg-white rounded-2xl border border-slate-100 shadow-sm p-12 text-center">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto text-slate-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h3 class="text-lg text-slate-700 mb-2">Nu există date importate</h3>
            <p class="text-sm text-slate-500 max-w-md mx-auto">
              Importați date din little-spider rulând:
              <code class="block mt-2 bg-slate-100 rounded px-3 py-2 text-xs">mix run priv/repo/import_from_export.exs</code>
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            <%= for group <- filtered_groups(@groups, @filters) do %>
              <.group_card group={group} />
            <% end %>
          </div>
        </main>
      </div>
    </div>
    """
  end

  defp filter_panel(assigns) do
    ~H"""
    <form phx-change="filter" class="space-y-4">
      <div>
        <label class="block text-xs text-slate-500 mb-1">Căutare</label>
        <input
          type="text"
          name="search"
          value={@filters.search}
          placeholder="Cuvânt cheie..."
          class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
        />
      </div>

      <div>
        <label class="block text-xs text-slate-500 mb-1">Oraș</label>
        <select name="city" class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent">
          <option value="">Toate</option>
          <%= for city <- @cities do %>
            <option value={city} selected={@filters.city == city}><%= city %></option>
          <% end %>
        </select>
      </div>

      <div>
        <label class="block text-xs text-slate-500 mb-1">Cartier</label>
        <select name="district" class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent">
          <option value="">Toate</option>
          <%= for district <- @districts do %>
            <option value={district} selected={@filters.district == district}><%= district %></option>
          <% end %>
        </select>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <div>
          <label class="block text-xs text-slate-500 mb-1">Preț min</label>
          <input type="number" name="min_price" value={@filters.min_price} placeholder="€" class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" />
        </div>
        <div>
          <label class="block text-xs text-slate-500 mb-1">Preț max</label>
          <input type="number" name="max_price" value={@filters.max_price} placeholder="€" class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" />
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <div>
          <label class="block text-xs text-slate-500 mb-1">mp min</label>
          <input type="number" name="min_sqm" value={@filters.min_sqm} placeholder="m²" class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" />
        </div>
        <div>
          <label class="block text-xs text-slate-500 mb-1">mp max</label>
          <input type="number" name="max_sqm" value={@filters.max_sqm} placeholder="m²" class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent" />
        </div>
      </div>

      <div class="space-y-2">
        <label class="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" name="with_parking" checked={@filters.with_parking} phx-click="toggle_parking" class="rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
          <span class="text-sm text-slate-700">Cu parcare</span>
        </label>
        <label class="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" name="with_commission" checked={@filters.with_commission} phx-click="toggle_commission" class="rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" />
          <span class="text-sm text-slate-700">Cu comision</span>
        </label>
      </div>

      <button type="button" phx-click="reset_filters" class="w-full px-3 py-2 text-sm text-slate-600 border border-slate-200 rounded-lg hover:bg-slate-50">
        Resetează filtre
      </button>
    </form>
    """
  end

  defp group_card(assigns) do
    ~H"""
    <.link navigate={~p"/listari/#{@group.id}"} class="block bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-shadow overflow-hidden">
      <div class="h-40 bg-slate-200 relative">
        <%= if @group.image_url do %>
          <img src={@group.image_url} alt="" class="w-full h-full object-cover" />
        <% else %>
          <div class="w-full h-full flex items-center justify-center text-slate-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-10 h-10" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
          </div>
        <% end %>
        <div class="absolute top-2 right-2 bg-white/90 backdrop-blur-sm rounded-lg px-2 py-1 text-xs text-slate-600">
          <%= @group.active_listings %>/<%= @group.total_listings %> active
        </div>
      </div>
      <div class="p-4">
        <div class="flex items-center gap-1.5 text-xs text-slate-500 mb-2">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          <%= @group.city %><%= if @group.district, do: " • #{@group.district}" %>
        </div>
        <h3 class="text-sm text-slate-800 line-clamp-2 mb-3"><%= @group.zone || @group.district || "Apartament" %></h3>
        <div class="flex items-center justify-between">
          <div>
            <span class="text-lg text-slate-900">€<%= format_price(@group.average_price) %></span>
            <span class="text-xs text-slate-400 ml-1">medie</span>
          </div>
          <span class="text-xs text-slate-500"><%= days_label(@group.days_on_market) %></span>
        </div>
        <div class="flex items-center gap-3 mt-2 text-xs text-slate-500">
          <span><%= @group.surface_area && round(@group.surface_area) %> m²</span>
          <span><%= @group.floor && "#{@group.floor}/#{@group.total_floors}" %></span>
        </div>
      </div>
    </.link>
    """
  end
end
