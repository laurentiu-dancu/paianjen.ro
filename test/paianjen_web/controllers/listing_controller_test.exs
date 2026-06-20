defmodule PaianjenWeb.ListingControllerTest do
  use PaianjenWeb.ConnCase

  test "GET /api/listings returns listings", %{conn: conn} do
    conn = get(conn, ~p"/api/listings")
    assert html_response(conn, 200)
  end
end
