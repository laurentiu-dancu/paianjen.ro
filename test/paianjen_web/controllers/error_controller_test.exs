defmodule PaianjenWeb.ErrorControllerTest do
  use PaianjenWeb.ConnCase

  test "renders 404", %{conn: conn} do
    conn = get(conn, ~p"/nonexistent")
    assert response(conn, 404)
  end
end
