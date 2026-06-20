defmodule PaianjenWeb.Router do
  use PaianjenWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PaianjenWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PaianjenWeb do
    pipe_through :browser

    live "/", PageLive, :index
    live "/listari", ListingLive.Index, :index
    live "/listari/:id", ListingLive.Show, :show
  end

  if Application.compile_env(:paianjen, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PaianjenWeb.Telemetry
    end
  end
end
