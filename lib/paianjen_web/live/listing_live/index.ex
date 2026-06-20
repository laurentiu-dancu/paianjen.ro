defmodule PaianjenWeb.ListingLive.Index do
  use PaianjenWeb, :live_view

  alias Paianjen.Listings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Anunțuri")
     |> assign(:filters, %{})
     |> assign(:listings, sample_listings())
     |> assign(:loading, false)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filters = %{
      min_price: params["min_price"],
      max_price: params["max_price"],
      rooms: params["rooms"],
      seller_type: params["seller_type"],
      district: params["district"]
    }

    {:noreply, assign(socket, filters: filters)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, assign(socket, filters: Map.merge(socket.assigns.filters, params), loading: true)}
  end

  @impl true
  def handle_info(:clear_loading, socket) do
    {:noreply, assign(socket, loading: false)}
  end

  # HTMX: handle filter form submission via live event
  @impl true
  def handle_event("search", params, socket) do
    # Simulate search delay
    send(self(), :clear_loading)
    {:noreply, assign(socket, filters: params)}
  end

  defp sample_listings do
    [
      %{
        id: 1,
        title: "Apartament 2 camere, mobilat, Zorilor",
        price: 85_000,
        rooms: 2,
        surface: 52,
        floor: 3,
        seller_type: :private,
        district: "Zorilor",
        first_discovered: ~D[2026-06-18],
        image_url: nil,
        description: "Apartament frumos, mobilat, în zona Zorilor. Ideal pentru cuplu."
      },
      %{
        id: 2,
        title: "Garsoneră renovată, Marăști",
        price: 55_000,
        rooms: 1,
        surface: 32,
        floor: 1,
        seller_type: :private,
        district: "Mărăști",
        first_discovered: ~D[2026-06-19],
        image_url: nil,
        description: "Garsoneră complet renovată, centrală termică proprie."
      },
      %{
        id: 3,
        title: "Apartament 3 camere, Gruia",
        price: 120_000,
        rooms: 3,
        surface: 75,
        floor: 5,
        seller_type: :agency,
        district: "Gruia",
        first_discovered: ~D[2026-06-15],
        image_url: nil,
        description: "Apartament spațios în zona Gruia, vedere panoramică."
      },
      %{
        id: 4,
        title: "Casă 4 camere, Grădinile Mănăștur",
        price: 195_000,
        rooms: 4,
        surface: 120,
        floor: 0,
        seller_type: :private,
        district: "Mănăștur",
        first_discovered: ~D[2026-06-20],
        image_url: nil,
        description: "Casă cu curte, 4 camere, garaj. Proprietar direct."
      },
      %{
        id: 5,
        title: "Apartament 2 camere, Centru",
        price: 98_000,
        rooms: 2,
        surface: 48,
        floor: 2,
        seller_type: :private,
        district: "Centru",
        first_discovered: ~D[2026-06-17],
        image_url: nil,
        description: "Apartament în centrul orașului, complet mobilat și utilat."
      }
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-stone-900">Anunțuri imobiliare</h1>
        <p class="mt-1 text-sm text-stone-500">
          Sortate după dată — cele mai noi primele
        </p>
      </div>

      <div class="flex flex-col lg:flex-row gap-8">
        <%!-- Filter sidebar --%>
        <aside class="w-full lg:w-72 flex-shrink-0">
          <.filters_form filters={@filters} />
        </aside>

        <%!-- Listings grid --%>
        <div class="flex-1">
          <div id="listings-grid" class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.listing_card :for={listing <- @listings} listing={listing} />
          </div>

          <div :if={@loading} class="text-center py-12">
            <span class="text-stone-400">Se încarcă...</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp filters_form(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-stone-200 p-6 shadow-sm">
      <h2 class="text-lg font-semibold text-stone-800 mb-4">Filtre</h2>

      <form
        id="filters-form"
        phx-change="filter"
        phx-submit="search"
        class="space-y-5"
      >
        <%!-- Price range --%>
        <div>
          <label class="block text-sm font-medium text-stone-700 mb-1">Preț (EUR)</label>
          <div class="flex items-center gap-2">
            <input
              type="number"
              name="min_price"
              value={@filters[:min_price]}
              placeholder="Min"
              class="w-full rounded-lg border-stone-300 text-sm focus:border-amber-500 focus:ring-amber-500"
            />
            <span class="text-stone-400">—</span>
            <input
              type="number"
              name="max_price"
              value={@filters[:max_price]}
              placeholder="Max"
              class="w-full rounded-lg border-stone-300 text-sm focus:border-amber-500 focus:ring-amber-500"
            />
          </div>
        </div>

        <%!-- Rooms --%>
        <div>
          <label class="block text-sm font-medium text-stone-700 mb-1">Camere</label>
          <select
            name="rooms"
            class="w-full rounded-lg border-stone-300 text-sm focus:border-amber-500 focus:ring-amber-500"
          >
            <option value="">Toate</option>
            <option value="1" selected={@filters[:rooms] == "1"}>1 cameră</option>
            <option value="2" selected={@filters[:rooms] == "2"}>2 camere</option>
            <option value="3" selected={@filters[:rooms] == "3"}>3 camere</option>
            <option value="4" selected={@filters[:rooms] == "4"}>4+ camere</option>
          </select>
        </div>

        <%!-- Seller type --%>
        <div>
          <label class="block text-sm font-medium text-stone-700 mb-1">Vânzător</label>
          <select
            name="seller_type"
            class="w-full rounded-lg border-stone-300 text-sm focus:border-amber-500 focus:ring-amber-500"
          >
            <option value="">Toți</option>
            <option value="private" selected={@filters[:seller_type] == "private"}>Persoană fizică</option>
            <option value="agency" selected={@filters[:seller_type] == "agency"}>Agenție</option>
          </select>
        </div>

        <%!-- District --%>
        <div>
          <label class="block text-sm font-medium text-stone-700 mb-1">Zonă</label>
          <select
            name="district"
            class="w-full rounded-lg border-stone-300 text-sm focus:border-amber-500 focus:ring-amber-500"
          >
            <option value="">Toate zonele</option>
            <option value="Centru" selected={@filters[:district] == "Centru"}>Centru</option>
            <option value="Zorilor" selected={@filters[:district] == "Zorilor"}>Zorilor</option>
            <option value="Mărăști" selected={@filters[:district] == "Mărăști"}>Mărăști</option>
            <option value="Gruia" selected={@filters[:district] == "Gruia"}>Gruia</option>
            <option value="Mănăștur" selected={@filters[:district] == "Mănăștur"}>Mănăștur</option>
          </select>
        </div>

        <button
          type="submit"
          class="w-full rounded-lg bg-amber-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-amber-600 transition-colors"
        >
          Caută
        </button>
      </form>
    </div>
    """
  end

  defp listing_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/listings/#{@listing.id}"}
      class="group bg-white rounded-xl border border-stone-200 overflow-hidden shadow-sm hover:shadow-md hover:border-amber-200 transition-all"
    >
      <%!-- Image placeholder --%>
      <div class="aspect-[4/3] bg-stone-100 flex items-center justify-center">
        <span class="text-4xl text-stone-300">🏠</span>
      </div>

      <div class="p-4">
        <div class="flex items-start justify-between gap-2">
          <h3 class="font-semibold text-stone-800 group-hover:text-amber-600 transition-colors line-clamp-2">
            <%= @listing.title %>
          </h3>
          <span class={[
            "shrink-0 text-xs font-medium px-2 py-0.5 rounded-full",
            @listing.seller_type == :private && "bg-emerald-50 text-emerald-700",
            @listing.seller_type == :agency && "bg-blue-50 text-blue-700"
          ]}>
            <%= if @listing.seller_type == :private, do: "Privat", else: "Agenție" %>
          </span>
        </div>

        <div class="mt-2 text-lg font-bold text-amber-600">
          <%= Number.Delimit.number_to_delimited(@listing.price, precision: 0) %> €
        </div>

        <div class="mt-3 flex items-center gap-3 text-sm text-stone-500">
          <span><%= @listing.rooms %> <%= if @listing.rooms == 1, do: "cameră", else: "camere" %></span>
          <span>·</span>
          <span><%= @listing.surface %> m²</span>
          <span>·</span>
          <span><%= @listing.district %></span>
        </div>

        <div class="mt-2 text-xs text-stone-400">
          Descoperit: <%= Calendar.strftime(@listing.first_discovered, "%d.%m.%Y") %>
        </div>
      </div>
    </.link>
    """
  end
end
