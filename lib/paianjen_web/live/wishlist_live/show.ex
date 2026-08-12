defmodule PaianjenWeb.WishlistLive.Show do
  @moduledoc """
  The shared wishlist ("colecție") page, reachable at `/colectii/:id`.

  Anyone with the uuid + the public password can VIEW the list. The hearts on
  each card always reflect — and toggle — the *viewer's own* wishlist (keyed by
  the session), so a guest browsing a shared list can save interesting groups
  to their own collection in place. Only the session that owns the list id is
  the "owner" (used for the header + share-link box).
  """
  use PaianjenWeb, :live_view

  alias Paianjen.Listings
  alias Paianjen.Listings.GroupPresenter
  import PaianjenWeb.ListingCard, only: [listing_card: 1]

  @impl true
  def mount(%{"id" => viewed_wishlist_id}, session, socket) do
    session_wishlist_id = session["wishlist_id"]

    if Listings.wishlist_exists?(viewed_wishlist_id) do
      groups =
        viewed_wishlist_id
        |> Listings.list_wishlist_entries()
        |> Enum.map(fn entry ->
          listings = entry.group.listings || Listings.list_listings_for_group(entry.group.id)
          GroupPresenter.from_group(entry.group, listings)
        end)

      {:ok,
       assign(socket,
         page_title: "Colecție",
         session_wishlist_id: session_wishlist_id,
         is_owner: session_wishlist_id == viewed_wishlist_id,
         groups: groups,
         total_count: length(groups),
         not_found: false,
         wishlist_ids:
           if(session_wishlist_id,
             do: Listings.wishlist_group_ids(session_wishlist_id),
             else: []
           )
       )}
    else
      {:ok,
       assign(socket,
         page_title: "Colecție",
         session_wishlist_id: session_wishlist_id,
         is_owner: false,
         groups: [],
         total_count: 0,
         not_found: true,
         wishlist_ids: []
       )}
    end
  end

  @impl true
  def handle_event("toggle_wishlist", %{"group_id" => group_id}, socket) do
    # The group_id comes from the event, but the wishlist written to is always
    # the viewer's own (from the session). There is no code path that writes
    # to a wishlist chosen by the client.
    case socket.assigns.session_wishlist_id do
      nil ->
        {:noreply, socket}

      session_wishlist_id ->
        case Listings.toggle_wishlist_item(session_wishlist_id, group_id) do
          {:ok, _added_or_removed} ->
            {:noreply,
             assign(socket, wishlist_ids: Listings.wishlist_group_ids(session_wishlist_id))}

          {:error, :wishlist_full} ->
            {:noreply,
             put_flash(socket, :error, "Colecția a atins limita de 200 de proprietăți.")}

          _other ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50">
      <main class="max-w-[1400px] mx-auto px-2 md:px-4 py-3 md:py-6">
        <div class="flex flex-wrap items-start justify-between gap-3 mb-6">
          <div>
            <h1 class="text-2xl md:text-3xl text-slate-900">
              <%= if @is_owner, do: "Colecția mea", else: "Colecție partajată" %>
            </h1>
            <p class="text-sm text-slate-500 mt-1">
              <%= if @is_owner do %>
                <%= @total_count %> proprietăți salvate.
              <% else %>
                O colecție de proprietăți salvate de un prieten — inimile de pe carduri reflectă colecția ta.
              <% end %>
            </p>
          </div>
        </div>

        <div :if={@not_found} class="bg-white rounded-2xl border border-slate-100 shadow-sm p-12 text-center">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto text-slate-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
          </svg>
          <h3 class="text-lg text-slate-700 mb-2">Colecția nu a fost găsită</h3>
          <p class="text-sm text-slate-500 max-w-md mx-auto mb-4">
            Verifică linkul sau cere-l din nou de la persoana care ți l-a trimis.
          </p>
          <.link navigate={~p"/listari"} class="text-indigo-600 hover:text-indigo-700 text-sm">
            Înapoi la listări
          </.link>
        </div>

        <div :if={@total_count == 0 and !@not_found} class="bg-white rounded-2xl border border-slate-100 shadow-sm p-12 text-center">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto text-slate-300 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
          </svg>
          <h3 class="text-lg text-slate-700 mb-2">Colecția e goală</h3>
          <p class="text-sm text-slate-500 max-w-md mx-auto mb-4">
            Salvează apartamente apăsând pe inimă din listări sau din pagina de detaliu.
          </p>
          <.link navigate={~p"/listari"} class="text-indigo-600 hover:text-indigo-700 text-sm">
            Explorează listările
          </.link>
        </div>

        <div :if={@total_count > 0} class="space-y-4">
          <%= for group <- @groups do %>
            <.listing_card group={group} wishlist_id={@session_wishlist_id} wishlist_ids={@wishlist_ids} />
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
