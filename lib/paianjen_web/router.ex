defmodule PaianjenWeb.Router do
  use PaianjenWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PaianjenWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # HTMX: detect HTMX requests
    plug :htmx_request_type
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PaianjenWeb do
    pipe_through :browser

    live "/", PageLive, :index
    live "/listings", ListingLive.Index, :index
    live "/listings/:id", ListingLive.Show, :show
  end

  scope "/api", PaianjenWeb do
    pipe_through :api

    # HTMX partial endpoints — return HTML fragments
    get "/listings", ListingController, :index
  end

  if Application.compile_env(:paianjen, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PaianjenWeb.Telemetry
    end
  end

  # Detect HTMX request type for conditional rendering
  defp htmx_request_type(conn, _opts) do
    case get_req_header(conn, "hx-request") do
      [] -> assign(conn, :htmx_request, false)
      _ -> assign(conn, :htmx_request, true)
    end
  end
end
