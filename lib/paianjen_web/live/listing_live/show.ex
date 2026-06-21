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
      |> Enum.take(5)
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

          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm text-gray-500 mb-1">Preț mediu</div>
              <div class="text-xl text-gray-900">€<%= format_price(@group.average_price) %></div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm text-gray-500 mb-1">Suprafață</div>
              <div class="text-xl text-gray-900"><%= @group.surface_area && round(@group.surface_area) %> m²</div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm text-gray-500 mb-1">Etaj</div>
              <div class="text-xl text-gray-900"><%= etaj_label(@group.floor, @group.total_floors) %></div>
            </div>
            <div class="bg-gray-50 rounded-lg p-4">
              <div class="text-sm text-gray-500 mb-1">An construcție</div>
              <div class="text-xl text-gray-900"><%= @group.year_built || "N/A" %></div>
            </div>
          </div>
        </div>

        <%!-- Listings in group --%>
        <div class="bg-white rounded-lg shadow-md p-6 mb-6">
          <h2 class="text-lg text-gray-900 mb-4">Listări în acest grup (<%= length(@group.listings) %>)</h2>
          <div class="space-y-3">
            <%= for listing <- @group.listings do %>
              <div class={["border border-gray-200 rounded-lg p-4", listing[:is_delisted] && "opacity-50"]}>
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <span class={["text-xs px-2 py-0.5 rounded-full", (if listing[:is_private], do: "bg-green-100 text-green-700", else: "bg-blue-100 text-blue-700")]}>
                        <%= if listing[:is_private], do: "Privat", else: "Agenție" %>
                      </span>
                      <span class="text-xs text-gray-500"><%= listing[:source] %></span>
                      <%= if listing[:is_delisted] do %>
                        <span class="text-xs px-2 py-0.5 rounded-full bg-red-100 text-red-700">Delistat</span>
                      <% end %>
                    </div>
                    <h3 class="text-sm text-gray-800 mb-2"><%= listing[:title] %></h3>
                    <div class="flex items-center gap-4 text-sm text-gray-600">
                      <span class="text-lg text-gray-900">€<%= format_price(listing[:price]) %></span>
                      <span><%= listing[:surface_area] && round(listing[:surface_area]) %> m²</span>
                      <span><%= listing[:floor] && "#{listing[:floor]}/#{listing[:total_floors]}" %></span>
                      <span><%= listing[:price_per_sqm] && "€#{round(listing[:price_per_sqm])}/m²" %></span>
                    </div>
                  </div>
                  <a :if={listing[:url]} href={listing[:url]} target="_blank" class="text-indigo-600 hover:text-indigo-800 text-sm">
                    Vezi original →
                  </a>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Similar Groups --%>
        <%
          similar = similar_groups_from_all(@group, @all_groups)
        %>
        <div :if={similar != []} class="bg-white rounded-lg shadow-md p-6">
          <h2 class="text-lg text-gray-900 mb-4">Grupuri similare</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for sg <- similar do %>
              <.link navigate={~p"/listari/#{sg.id}"} class="block border border-gray-200 rounded-lg p-4 hover:border-indigo-300 transition-colors">
                <div class="flex items-center gap-1.5 text-xs text-gray-500 mb-2">
                  <span><%= sg.city %></span>
                  <span>•</span>
                  <span><%= sg.district %></span>
                </div>
                <h3 class="text-sm text-gray-800 mb-2"><%= sg.zone || sg.district %></h3>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-gray-900">€<%= format_price(sg.average_price) %></span>
                  <span class="text-gray-500"><%= sg.surface_area && round(sg.surface_area) %> m²</span>
                </div>
              </.link>
            <% end %>
          </div>
        </div>
      </main>

      <main :if={!@group} class="max-w-7xl mx-auto px-4 py-8">
        <div class="bg-white rounded-lg shadow-md p-12 text-center">
          <h2 class="text-xl text-gray-700 mb-2">Grupul nu a fost găsit</h2>
          <.link navigate={~p"/listari"} class="text-indigo-600 hover:text-indigo-800">Înapoi la listări</.link>
        </div>
      </main>
    </div>
    """
  end
end
