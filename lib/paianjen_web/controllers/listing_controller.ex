defmodule PaianjenWeb.ListingController do
  use PaianjenWeb, :controller

  def index(conn, params) do
    # HTMX endpoint — returns HTML fragments for partial page updates
    listings = PaianjenWeb.ListingLive.Index.sample_listings()

    listings =
      listings
      |> maybe_filter_by_seller_type(params["seller_type"])
      |> maybe_filter_by_rooms(params["rooms"])
      |> maybe_filter_by_district(params["district"])

    conn
    |> put_resp_content_type("text/html")
    |> render(:index, listings: listings)
  end

  defp maybe_filter_by_seller_type(listings, nil), do: listings
  defp maybe_filter_by_seller_type(listings, ""), do: listings

  defp maybe_filter_by_seller_type(listings, type) do
    type_atom = String.to_existing_atom(type)
    Enum.filter(listings, &(&1.seller_type == type_atom))
  end

  defp maybe_filter_by_rooms(listings, nil), do: listings
  defp maybe_filter_by_rooms(listings, ""), do: listings

  defp maybe_filter_by_rooms(listings, rooms) do
    rooms_int = String.to_integer(rooms)
    Enum.filter(listings, &(&1.rooms == rooms_int))
  end

  defp maybe_filter_by_district(listings, nil), do: listings
  defp maybe_filter_by_district(listings, ""), do: listings

  defp maybe_filter_by_district(listings, district) do
    Enum.filter(listings, &(&1.district == district))
  end
end
