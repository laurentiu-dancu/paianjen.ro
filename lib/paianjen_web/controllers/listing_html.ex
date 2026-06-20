defmodule PaianjenWeb.ListingHTML do
  use PaianjenWeb, :html

  def index(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <.listing_card :for={listing <- @listings} listing={listing} />
    </div>
    """
  end

  defp listing_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/listings/#{@listing.id}"}
      class="group bg-white rounded-xl border border-stone-200 overflow-hidden shadow-sm hover:shadow-md hover:border-amber-200 transition-all"
    >
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
      </div>
    </.link>
    """
  end
end
