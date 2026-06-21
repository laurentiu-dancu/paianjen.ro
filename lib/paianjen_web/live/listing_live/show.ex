defmodule PaianjenWeb.ListingLive.Show do
  use PaianjenWeb, :live_view

  alias Paianjen.Listings
  alias Paianjen.Listings.GroupPresenter

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    group = load_group(id)
    all_groups = load_all_groups()

    {:ok,
     assign(socket,
       page_title: (group && (group.zone || group.district)) || "Detalii",
       group: group,
       all_groups: all_groups
     )}
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

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %B %Y")
  end

  defp format_date(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%d %B %Y")
  end

  defp format_date(_), do: "N/A"

  defp etaj_label(nil, _), do: "N/A"
  defp etaj_label(0, _), do: "Parter"
  defp etaj_label(floor, total), do: "#{floor}/#{total}"

  defp load_group(id) do
    group = Listings.get_group!(id)
    listings = group.listings || Listings.list_listings_for_group(id)
    GroupPresenter.from_group(group, listings)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp load_all_groups do
    case Listings.list_groups() do
      [] ->
        []

      groups ->
        groups
        |> Enum.map(fn g ->
          listings = g.listings || Listings.list_listings_for_group(g.id)
          GroupPresenter.from_group(g, listings)
        end)
    end
  end

  defp similar_groups_from_all(group, all_groups) do
    if group do
      all_groups
      |> Enum.filter(fn g ->
        g.id != group.id and
          g.average_price >= group.average_price * 0.85 and
          g.average_price <= group.average_price * 1.15 and
          g.surface_area >= group.surface_area * 0.7 and
          g.surface_area <= group.surface_area * 1.3
      end)
      |> Enum.take(3)
    else
      []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <%!-- Header --%>
      <header class="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-10">
        <div class="max-w-7xl mx-auto px-4 py-4">
          <.link navigate={~p"/listari"} class="flex items-center gap-2 text-gray-600 hover:text-gray-900">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Înapoi la listări
          </.link>
        </div>
      </header>

      <main :if={@group} class="max-w-7xl mx-auto px-4 py-8">
        <%!-- Property Overview --%>
        <div class="bg-white rounded-lg shadow-md p-6 mb-6 relative overflow-hidden">
          <.spider_web days_on_market={@group.days_on_market} />

          <div class="flex items-start justify-between mb-6">
            <div>
              <div class="flex items-center gap-2 text-gray-600 mb-2">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <span class="text-lg">
                  <%= @group.city %><%= if @group.district, do: " • #{@group.district}" %>
                </span>
              </div>
              <h1 :if={@group.zone} class="text-2xl text-gray-900 mb-4"><%= @group.zone %></h1>
            </div>

            <div class="flex items-center gap-3">
              <div class="text-right">
                <div class="flex items-center gap-2 text-sm text-gray-600 mb-1">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M8 7V3m4 4V3m-4 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <span><%= @group.days_on_market %> <%= if @group.days_on_market == 1, do: "zi", else: "zile" %> pe piață</span>
                </div>
                <%
                  health_pct = @group.health_pct
                  health_color = cond do
                    health_pct >= 75 -> "text-green-600"
                    health_pct >= 50 -> "text-yellow-600"
                    true -> "text-orange-600"
                  end
                %>
                <div class="flex items-center gap-2 text-sm">
                  <svg xmlns="http://www.w3.org/2000/svg" class={"w-4 h-4 #{health_color}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                  </svg>
                  <span class="text-gray-700">Sănătate: <%= @group.active_listings %>/<%= @group.total_listings %> active</span>
                </div>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                </svg>
              </div>
              <div>
                <p class="text-xs text-gray-500">Suprafață</p>
                <p class="text-lg text-gray-900"><%= @group.surface_area %>m²</p>
              </div>
            </div>

            <%= if @group.floor && @group.total_floors do %>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                </div>
                <div>
                  <p class="text-xs text-gray-500">Etaj</p>
                  <p class="text-lg text-gray-900"><%= etaj_label(@group.floor, @group.total_floors) %></p>
                </div>
              </div>
            <% end %>

            <%= if @group.year_built do %>
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                  </svg>
                </div>
                <div>
                  <p class="text-xs text-gray-500">An construcție</p>
                  <p class="text-lg text-gray-900"><%= @group.year_built %></p>
                </div>
              </div>
            <% end %>

            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-indigo-50 rounded-lg flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div>
                <p class="text-xs text-gray-500">Preț mediu</p>
                <p class="text-lg text-gray-900"><%= format_price(@group.average_price) %> €</p>
              </div>
            </div>
          </div>

          <%= if @group.image_url do %>
            <div class="rounded-lg overflow-hidden h-64">
              <img src={@group.image_url} alt={"Apartament în #{@group.zone || @group.district}"} class="w-full h-full object-cover" />
            </div>
          <% end %>
        </div>

        <%!-- Individual Listings --%>
        <%
          sorted_listings = @group.listings
          |> Enum.sort_by(fn l ->
            private_val = if l.is_private, do: 0, else: 1
            commission_val = if l.agency_commission == 0, do: 0, else: 1
            {private_val, commission_val, l.agency_commission}
          end)
        %>
        <div class="mb-8">
          <h2 class="text-xl text-gray-900 mb-4">Toate listările (<%= length(sorted_listings) %>)</h2>

          <div class="space-y-4">
            <%= for listing <- sorted_listings do %>
              <div class={"bg-white rounded-lg shadow-sm p-5 border #{if listing.delisted_date, do: "border-gray-200 opacity-60", else: "border-gray-100"}"}>
                <div class="flex items-start justify-between mb-4">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-2">
                      <h3 class="text-lg text-gray-900"><%= format_price(listing.price_with_vat) %> €</h3>
                      <%= if listing.is_private do %>
                        <span class="px-2 py-1 bg-green-50 text-green-700 text-xs rounded">Proprietar</span>
                      <% end %>
                      <%= if listing.agency_commission == 0 && !listing.is_private do %>
                        <span class="px-2 py-1 bg-blue-50 text-blue-700 text-xs rounded">Comision 0</span>
                      <% end %>
                      <%= if listing.delisted_date do %>
                        <span class="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">Dezlistat</span>
                      <% end %>
                    </div>
                    <p class="text-sm text-gray-700 mb-1 leading-snug"><%= listing.title %></p>
                    <p class="text-sm text-gray-600 mb-1"><%= format_price(listing.price_per_sqm) %> €/m² • <%= listing.surface_area %>m²</p>
                    <p class="text-sm text-gray-500"><%= listing.source %></p>
                  </div>

                  <div class="text-right text-sm">
                    <p class="text-gray-600 mb-1">Publicat: <%= format_date(listing.published_date) %></p>
                    <%= if listing.delisted_date do %>
                      <p class="text-gray-500">Dezlistat: <%= format_date(listing.delisted_date) %></p>
                    <% end %>
                  </div>
                </div>

                <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                  <%= if listing.floor && listing.total_floors do %>
                    <div>
                      <span class="text-gray-500">Etaj: </span>
                      <span class="text-gray-900"><%= etaj_label(listing.floor, listing.total_floors) %></span>
                    </div>
                  <% end %>

                  <%= if listing.balcony_surface do %>
                    <div>
                      <span class="text-gray-500">Balcon: </span>
                      <span class="text-gray-900"><%= listing.balcony_surface %>m²</span>
                    </div>
                  <% end %>

                  <%= if listing.parking_price do %>
                    <div class="flex items-center gap-1">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M8 7h8m-8 4h8m-4 4v4m-4-4h8a2 2 0 002-2V5a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                      <span class="text-gray-900"><%= format_price(listing.parking_price) %> €</span>
                    </div>
                  <% end %>

                  <%= if listing.agency_commission > 0 do %>
                    <div>
                      <span class="text-gray-500">Comision: </span>
                      <span class="text-orange-600"><%= format_price(listing.agency_commission) %> €</span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Similar Groups --%>
        <%
          similar_groups = similar_groups_from_all(@group, @all_groups)
        %>
        <%= if length(similar_groups) > 0 do %>
          <div>
            <div class="flex items-center gap-2 mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
              <h2 class="text-xl text-gray-900">Proprietăți similare</h2>
            </div>
            <p class="text-sm text-gray-600 mb-4">
              Aceste proprietăți ar putea fi același apartament sau unul foarte similar. Gruparea este conservatoare pentru a evita erorile.
            </p>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <%= for sg <- similar_groups do %>
                <.link navigate={~p"/listari/#{sg.id}"} class="bg-white rounded-lg shadow-sm p-4 border border-amber-100 cursor-pointer hover:shadow-md transition-shadow block">
                  <div class="flex items-center gap-2 text-gray-600 text-sm mb-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <span><%= sg.zone || sg.district %></span>
                  </div>
                  <p class="text-xl text-gray-900 mb-1"><%= format_price(sg.average_price) %> €</p>
                  <p class="text-sm text-gray-500 mb-3">
                    <%= format_price(sg.average_price / sg.surface_area) %> €/m² • <%= sg.surface_area %>m²
                  </p>
                  <div class="flex items-center justify-between text-xs text-gray-600">
                    <span><%= sg.days_on_market %> zile pe piață</span>
                    <span><%= sg.active_listings %>/<%= sg.total_listings %> active</span>
                  </div>
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      </main>

      <div :if={!@group} class="min-h-screen bg-gray-50 flex items-center justify-center">
        <div class="text-center">
          <p class="text-gray-600 mb-4">Proprietatea nu a fost găsită</p>
          <.link navigate={~p"/listari"} class="text-indigo-600 hover:text-indigo-700">Înapoi la listări</.link>
        </div>
      </div>
    </div>
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
