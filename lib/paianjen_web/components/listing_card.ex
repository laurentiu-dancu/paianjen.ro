defmodule PaianjenWeb.ListingCard do
  @moduledoc """
  Shared listing card used by the /listari index and the /colectii wishlist
  page. Also exposes `wishlist_heart/1`, the heart button used on cards and on
  the detail page.

  The heart is rendered as an absolutely-positioned overlay *sibling* of the
  card link (both inside a `relative` wrapper), never nested inside the
  `<a>`. A nested `<button>` would be invalid HTML and clicks would bubble into
  navigation (and into the card-click interception in app.js).
  """
  use PaianjenWeb, :html

  import PaianjenWeb.CoreComponents

  attr :group, :map, required: true
  attr :wishlist_id, :string, default: nil
  attr :wishlist_ids, :list, default: []
  attr :show_wishlist_button, :boolean, default: true

  def listing_card(assigns) do
    ~H"""
    <div class="relative">
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

                <%= if @group.has_price_drop do %>
                  <span class="flex items-center gap-1 text-emerald-600" title="Ultima reducere de preț">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3 7l6 6 4-4 8 8m0 0h-5m5 0v-5" />
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

      <.wishlist_heart
        :if={@show_wishlist_button and @wishlist_id}
        group_id={@group.id}
        saved={@group.id in @wishlist_ids}
      />
    </div>
    """
  end

  attr :group_id, :string, required: true
  attr :saved, :boolean, default: false

  def wishlist_heart(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="toggle_wishlist"
      phx-value-group_id={@group_id}
      phx-stop-propagation
      aria-label={if @saved, do: "Șterge din colecție", else: "Adaugă în colecție"}
      title={if @saved, do: "Șterge din colecție", else: "Adaugă în colecție"}
      class={"absolute bottom-2 left-2 z-20 flex items-center justify-center w-9 h-9 rounded-full bg-white/90 backdrop-blur shadow-md border border-slate-100 cursor-pointer transition-all hover:scale-110 active:scale-95 #{if @saved, do: "opacity-100", else: "opacity-40 hover:opacity-100"}"}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class={"w-5 h-5 #{if @saved, do: "text-rose-500", else: "text-slate-400 hover:text-rose-400"}"}
        fill={if @saved, do: "currentColor", else: "none"}
        viewBox="0 0 24 24"
        stroke="currentColor"
        stroke-width="2"
      >
        <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
      </svg>
    </button>
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

  defp pad_zero(n) when n < 10, do: "0#{n}"
  defp pad_zero(n), do: to_string(n)
end
