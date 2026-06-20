defmodule PaianjenWeb.ListingLive.Show do
  use PaianjenWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    listing = get_listing(id)

    {:ok,
     socket
     |> assign(:page_title, listing.title)
     |> assign(:listing, listing)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <.link
        navigate={~p"/listings"}
        class="inline-flex items-center gap-1 text-sm text-stone-500 hover:text-amber-600 transition-colors mb-6"
      >
        <span>←</span>
        <span>Înapoi la anunțuri</span>
      </.link>

      <div class="bg-white rounded-xl border border-stone-200 shadow-sm overflow-hidden">
        <%!-- Image gallery placeholder --%>
        <div class="aspect-[16/9] bg-stone-100 flex items-center justify-center">
          <span class="text-6xl text-stone-300">🏠</span>
        </div>

        <div class="p-6 sm:p-8">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold text-stone-900"><%= @listing.title %></h1>
              <div class="mt-2 flex items-center gap-2">
                <span class={[
                  "text-xs font-medium px-2 py-0.5 rounded-full",
                  @listing.seller_type == :private && "bg-emerald-50 text-emerald-700",
                  @listing.seller_type == :agency && "bg-blue-50 text-blue-700"
                ]}>
                  <%= if @listing.seller_type == :private, do: "Persoană fizică", else: "Agenție" %>
                </span>
                <span class="text-sm text-stone-400">
                  <%= @listing.district %>
                </span>
              </div>
            </div>
            <div class="text-3xl font-bold text-amber-600">
              <%= Number.Delimit.number_to_delimited(@listing.price, precision: 0) %> €
            </div>
          </div>

          <%!-- Features --%>
          <div class="mt-8 grid grid-cols-2 sm:grid-cols-4 gap-4">
            <.feature_item label="Camere" value={"#{@listing.rooms}"} />
            <.feature_item label="Suprafață" value={"#{@listing.surface} m²"} />
            <.feature_item label="Etaj" value={etaj_label(@listing.floor)} />
            <.feature_item label="Zonă" value={@listing.district} />
          </div>

          <%!-- Description --%>
          <div class="mt-8">
            <h2 class="text-lg font-semibold text-stone-800 mb-3">Descriere</h2>
            <p class="text-stone-600 leading-relaxed"><%= @listing.description %></p>
          </div>

          <%!-- Meta --%>
          <div class="mt-8 pt-6 border-t border-stone-100 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div class="text-sm text-stone-400">
              Descoperit: <%= Calendar.strftime(@listing.first_discovered, "%d.%m.%Y") %>
            </div>
            <a
              href="#"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 rounded-lg bg-stone-100 px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-200 transition-colors"
            >
              <span>Vezi anunțul original</span>
              <span aria-hidden="true">↗</span>
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp feature_item(assigns) do
    ~H"""
    <div class="bg-stone-50 rounded-lg p-3 text-center">
      <div class="text-xs text-stone-400 uppercase tracking-wide"><%= @label %></div>
      <div class="mt-1 font-semibold text-stone-800"><%= @value %></div>
    </div>
    """
  end

  defp etaj_label(0), do: "Parter"
  defp etaj_label(floor), do: "Etaj #{floor}"

  defp get_listing(id) do
    # Stub — will be replaced with DB lookup
    listings = %{
      "1" => %{
        id: 1,
        title: "Apartament 2 camere, mobilat, Zorilor",
        price: 85_000,
        rooms: 2,
        surface: 52,
        floor: 3,
        seller_type: :private,
        district: "Zorilor",
        first_discovered: ~D[2026-06-18],
        description: "Apartament frumos, mobilat, în zona Zorilor. Ideal pentru cuplu. Situat la etajul 3, cu vedere spre grădina zoologică. Bucătărie deschisă, baie modernă, balcon de 6m²."
      },
      "2" => %{
        id: 2,
        title: "Garsoneră renovată, Marăști",
        price: 55_000,
        rooms: 1,
        surface: 32,
        floor: 1,
        seller_type: :private,
        district: "Mărăști",
        first_discovered: ~D[2026-06-19],
        description: "Garsoneră complet renovată, centrală termică proprie. Ideală pentru studenți sau ca investiție."
      },
      "3" => %{
        id: 3,
        title: "Apartament 3 camere, Gruia",
        price: 120_000,
        rooms: 3,
        surface: 75,
        floor: 5,
        seller_type: :agency,
        district: "Gruia",
        first_discovered: ~D[2026-06-15],
        description: "Apartament spațios în zona Gruia, vedere panoramică. Comision 2%."
      },
      "4" => %{
        id: 4,
        title: "Casă 4 camere, Grădinile Mănăștur",
        price: 195_000,
        rooms: 4,
        surface: 120,
        floor: 0,
        seller_type: :private,
        district: "Mănăștur",
        first_discovered: ~D[2026-06-20],
        description: "Casă cu curte, 4 camere, garaj. Proprietar direct, fără comisioane."
      },
      "5" => %{
        id: 5,
        title: "Apartament 2 camere, Centru",
        price: 98_000,
        rooms: 2,
        surface: 48,
        floor: 2,
        seller_type: :private,
        district: "Centru",
        first_discovered: ~D[2026-06-17],
        description: "Apartament în centrul orașului, complet mobilat și utilat. Proprietar vinde direct."
      }
    }

    Map.get(listings, to_string(id), hd(Map.values(listings)))
  end
end
