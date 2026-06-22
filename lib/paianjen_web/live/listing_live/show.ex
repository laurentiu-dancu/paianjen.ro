defmodule PaianjenWeb.ListingLive.Show do
  use PaianjenWeb, :live_view

  alias Paianjen.Listings
  alias Paianjen.Listings.GroupPresenter

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    group = load_group(id)
    similar_groups = load_similar_groups(id)

    {:ok,
     assign(socket,
       page_title: (group && (group.zone || group.district)) || "Detalii",
       group: group,
       group_id: id,
       return_to: params["return_to"],
       similar_groups: similar_groups
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

  defp days_label(0), do: "Astăzi"
  defp days_label(1), do: "1 zi pe piață"
  defp days_label(n), do: "#{n} zile pe piață"

  defp etaj_label(nil, _), do: "N/A"
  defp etaj_label(0, _), do: "Parter"
  defp etaj_label(-1, _), do: "Demisol sau Mansarda"
  defp etaj_label(floor, nil), do: "#{floor}"
  defp etaj_label(floor, total), do: "#{floor}/#{total}"

  defp load_group(id) do
    group = Listings.get_group!(id)
    listings = group.listings || Listings.list_listings_for_group(id)
    GroupPresenter.from_group(group, listings)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp load_similar_groups(id) do
    similar_sgs = Listings.list_similar_groups(id)

    similar_sgs
    |> Enum.map(fn sg ->
      group = Listings.get_group!(sg.similar_group_id)
      listings = group.listings || Listings.list_listings_for_group(group.id)
      GroupPresenter.from_group(group, listings)
    end)
    |> Enum.filter(fn g -> g.has_active_listings end)
  rescue
    Ecto.NoResultsError -> []
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <%!-- Header --%>
      <header class="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-10">
        <div class="max-w-7xl mx-auto px-4 py-4">
          <a href={@return_to || ~p"/listari?cursor=#{@group_id}"} class="flex items-center gap-2 text-gray-600 hover:text-gray-900">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Înapoi la listări
          </a>
        </div>
      </header>

      <main :if={@group} class="max-w-7xl mx-auto px-4 py-6 md:py-10">
        <%!-- Property Overview --%>
        <div class="bg-white rounded-2xl shadow-sm border border-slate-100 p-5 md:p-8 mb-6 md:mb-8 relative overflow-hidden">
          <.spider_web days_on_market={@group.days_on_market} />

          <%
            images = @group.listings
            |> Enum.flat_map(fn l -> l.images || [] end)
            |> Enum.uniq()
            |> Enum.take(10)
          %>
          <%= if length(images) > 0 do %>
            <div class="flex flex-col md:flex-row gap-6 md:gap-8">
              <%!-- Image slider --%>
              <div class="md:w-[48%] flex-shrink-0">
                <div id="image-slider" class="rounded-xl overflow-hidden relative bg-slate-100 aspect-[4/3]" phx-hook="ImageSlider" data-images={Jason.encode!(images)}>
                  <div class="absolute inset-0 flex items-center justify-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 text-slate-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21z" />
                    </svg>
                  </div>
                  <img src={Enum.at(images, 0)} alt={"Apartament în #{@group.zone || @group.district}"} class="relative w-full h-full object-cover bg-slate-100" id="slider-img" onerror="this.style.display='none';" />
                  <div class="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-2 z-10" id="slider-dots">
                    <%= for {_, i} <- Enum.with_index(images) do %>
                      <button
                        class={"w-2 h-2 rounded-full #{if i == 0, do: "bg-white", else: "bg-white/50"}"}
                        onclick="window.slideTo(#{i})"
                      ></button>
                    <% end %>
                  </div>
                  <%= if length(images) > 1 do %>
                    <button onclick="window.slidePrev()" class="absolute left-2 top-1/2 -translate-y-1/2 bg-black/40 hover:bg-black/60 text-white rounded-full w-9 h-9 flex items-center justify-center z-10">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7" /></svg>
                    </button>
                    <button onclick="window.slideNext()" class="absolute right-2 top-1/2 -translate-y-1/2 bg-black/40 hover:bg-black/60 text-white rounded-full w-9 h-9 flex items-center justify-center z-10">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" /></svg>
                    </button>
                  <% end %>
                </div>
              </div>

              <%!-- Title + price + key stats --%>
              <div class="flex-1 min-w-0 flex flex-col justify-center">
                <div class="flex items-center gap-2 text-slate-500 text-sm mb-1.5">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                  <span><%= @group.city %><%= if @group.district, do: " · #{@group.district}" %></span>
                </div>
                <h1 :if={@group.zone} class="text-2xl md:text-3xl text-slate-900 mb-2"><%= @group.zone %></h1>
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
                <p class="text-sm md:text-base text-slate-500 mb-4 line-clamp-2"><%= representative_title %></p>

                <div class="flex items-baseline gap-3 mb-5">
                  <span class="text-3xl md:text-4xl text-slate-900">
                    <%= if @group.min_price && @group.max_price && @group.min_price == @group.max_price, do: format_price(@group.min_price) <> " €", else: "de la " <> format_price(@group.min_price) <> " €" %>
                  </span>
                  <%= if @group.min_price && @group.min_surface do %>
                    <span class="text-sm md:text-base text-slate-400"><%= format_price(@group.min_price / @group.min_surface) %> €/m²</span>
                  <% end %>
                </div>

                <div class="flex flex-wrap gap-x-5 gap-y-2 text-sm text-slate-600">
                  <%= if @group.min_surface do %>
                    <span class="flex items-center gap-1.5">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" /></svg>
                      <%= if @group.max_surface && @group.min_surface == @group.max_surface, do: "#{round(@group.min_surface)}", else: "#{round(@group.min_surface)}–#{round(@group.max_surface)}" %> m²
                    </span>
                  <% end %>
                  <%= if @group.rooms do %>
                    <span class="flex items-center gap-1.5">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
                      <%= @group.rooms %> camere
                    </span>
                  <% end %>
                  <%= if @group.floor do %>
                    <span class="flex items-center gap-1.5">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                      Et. <%= etaj_label(@group.floor, @group.total_floors) %>
                    </span>
                  <% end %>
                  <%= if @group.parking_price do %>
                    <span class="flex items-center gap-1.5">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7h8m-8 4h8m-4 4v4m-4-4h8a2 2 0 002-2V5a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                      Parcare <%= format_price(@group.parking_price) %> €
                    </span>
                  <% end %>
                  <%= if @group.year_built do %>
                    <span class="flex items-center gap-1.5">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-slate-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>
                      An <%= @group.year_built %>
                    </span>
                  <% end %>
                  <span class="flex items-center gap-1.5">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-indigo-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                    <%= days_label(@group.days_on_market) %>
                  </span>
                  <span class="flex items-center gap-1.5">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-emerald-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                    <%= @group.active_listings %>/<%= @group.total_listings %> active
                  </span>
                </div>

              </div>
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
        <div class="mb-8 md:mb-10">
          <h2 class="text-xl md:text-2xl text-slate-900 mb-4 md:mb-6">Toate listările (<%= length(sorted_listings) %>)</h2>

          <div class="space-y-3 md:space-y-4">
            <%= for listing <- sorted_listings do %>
              <div class={"bg-white rounded-xl md:rounded-2xl shadow-sm border overflow-hidden relative #{if listing.delisted_date, do: "border-gray-200 opacity-60", else: "border-slate-100"}"}>
                <div class="flex gap-0">
                  <%!-- Thumbnail --%>
                  <div class="w-24 sm:w-32 md:w-40 flex-shrink-0 relative aspect-[4/3]">
                    <%= if listing.image_url do %>
                      <.image_with_fallback src={listing.image_url} alt={"Apartament"} class="absolute inset-0 w-full h-full" />
                    <% else %>
                      <.no_image_placeholder class="absolute inset-0 w-full h-full" />
                    <% end %>
                  </div>

                  <div class="flex-1 p-3 md:p-4 min-w-0">
                    <div class="flex items-start justify-between gap-3 mb-1.5 md:mb-2">
                      <div class="flex-1 min-w-0">
                        <div class="flex items-baseline gap-2 flex-wrap">
                          <span class="text-lg md:text-xl text-slate-900"><%= format_price(listing.price_with_vat) %> €</span>
                          <%= if listing.is_private do %>
                            <span class="px-1.5 py-0.5 bg-emerald-50 text-emerald-700 text-xs rounded-full border border-emerald-100">proprietar</span>
                          <% end %>
                          <%= if listing.agency_commission == 0 && !listing.is_private do %>
                            <span class="px-1.5 py-0.5 bg-blue-50 text-blue-700 text-xs rounded-full border border-blue-100">comision 0</span>
                          <% end %>
                          <%= if listing.agency_commission > 0 && !listing.is_private do %>
                            <% min_comm = listing.agency_commission %>
                            <span class="px-1.5 py-0.5 bg-orange-50 text-orange-700 text-xs rounded-full border border-orange-100">comision <%= format_price(min_comm) %> €</span>
                          <% end %>
                          <%= if listing.delisted_date do %>
                            <span class="px-1.5 py-0.5 bg-gray-100 text-gray-600 text-xs rounded">Dezlistat</span>
                          <% end %>
                        </div>
                        <p class="text-xs md:text-sm text-slate-600 mt-0.5 md:mt-1 leading-snug truncate"><%= listing.title %></p>
                      </div>

                      <div class="text-right text-xs text-slate-400 flex-shrink-0 hidden md:block">
                        <p>Publicat: <%= format_date(listing.published_date) %></p>
                        <%= if listing.delisted_date do %>
                          <p>Dezlistat: <%= format_date(listing.delisted_date) %></p>
                        <% end %>
                      </div>
                    </div>

                    <div class="flex flex-wrap items-center gap-x-3 md:gap-x-4 gap-y-1 text-xs text-slate-500">
                      <%= if listing.surface_area do %>
                        <span class="flex items-center gap-1">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" /></svg>
                          <%= listing.surface_area %> m²
                        </span>
                      <% end %>
                      <%= if listing.rooms do %>
                        <span class="flex items-center gap-1">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
                          <%= listing.rooms %> camere
                        </span>
                      <% end %>
                      <%= if listing.floor do %>
                        <span class="flex items-center gap-1">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                          Et. <%= etaj_label(listing.floor, listing.total_floors) %>
                        </span>
                      <% end %>
                      <%= if listing.parking_price do %>
                        <span class="flex items-center gap-1">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7h8m-8 4h8m-4 4v4m-4-4h8a2 2 0 002-2V5a2 2 0 00-2-2H6a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                          Parcare <%= format_price(listing.parking_price) %> €
                        </span>
                      <% end %>
                      <%= if listing.price_per_sqm do %>
                        <span class="text-slate-400"><%= format_price(listing.price_per_sqm) %> €/m²</span>
                      <% end %>
                    </div>

                    <div class="flex items-center justify-between mt-2 md:mt-3 pt-2 border-t border-slate-50">
                      <div class="flex items-center gap-2 text-xs text-slate-400">
                        <span><%= listing.source %></span>
                        <%= if listing.delisted_date do %>
                          <span>· <%= format_date(listing.delisted_date) %></span>
                        <% end %>
                      </div>
                      <%= if listing.url do %>
                        <a href={listing.url} target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-1 text-xs text-indigo-600 hover:text-indigo-800 font-medium">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                          Vezi anunțul original
                        </a>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Similar Groups --%>
        <%
          capped_similar = Enum.take(@similar_groups, 6)
        %>
        <%= if length(capped_similar) > 0 do %>
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

            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 md:gap-4">
              <%= for sg <- capped_similar do %>
                <a
                  href={~p"/listari/#{sg.id}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="bg-white border border-slate-100 rounded-xl md:rounded-2xl shadow-sm hover:shadow-md hover:border-indigo-100 transition-all cursor-pointer overflow-hidden relative block"
                >
                  <div class="relative aspect-[4/3] bg-slate-100">
                    <%= if sg.image_url do %>
                      <.image_with_fallback src={sg.image_url} alt={"Apartament"} class="absolute inset-0 w-full h-full" />
                    <% else %>
                      <.no_image_placeholder class="absolute inset-0 w-full h-full" />
                    <% end %>
                  </div>
                  <div class="p-2.5 md:p-3 min-w-0">
                    <div class="flex items-center gap-1 text-slate-400 text-xs mb-0.5">
                      <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                      <span class="truncate"><%= sg.zone || sg.district || sg.city %></span>
                    </div>
                    <p class="text-base md:text-lg text-slate-900 mb-0.5">
                      <%= if sg.max_price && sg.min_price == sg.max_price, do: format_price(sg.min_price) <> " €", else: "de la " <> format_price(sg.min_price) <> " €" %>
                    </p>
                    <p class="text-xs text-slate-400 mb-1">
                      <%= if sg.min_surface && sg.min_price, do: format_price(sg.min_price / sg.min_surface) <> " €/m²", else: "" %>
                    </p>
                    <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-slate-500">
                      <%= if sg.min_surface do %>
                        <span class="flex items-center gap-0.5">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" /></svg>
                          <%= round(sg.min_surface) %> m²
                        </span>
                      <% end %>
                      <%= if sg.rooms do %>
                        <span class="flex items-center gap-0.5">
                          <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
                          <%= sg.rooms %>
                        </span>
                      <% end %>
                    </div>
                  </div>
                </a>
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
