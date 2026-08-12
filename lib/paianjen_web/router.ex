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

  pipeline :authenticated do
    plug PaianjenWeb.AuthPlug
    plug PaianjenWeb.EnsureWishlistPlug
  end

  scope "/", PaianjenWeb do
    pipe_through :browser

    live "/", PageLive, :index
    post "/login", LoginController, :create
    delete "/logout", LoginController, :delete
  end

  scope "/", PaianjenWeb do
    pipe_through [:browser, :authenticated]

    live "/listari", ListingLive.Index, :index
    live "/listari/:id", ListingLive.Show, :show
    live "/colectii/:id", WishlistLive.Show, :show
  end

  if Application.compile_env(:paianjen, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: PaianjenWeb.Telemetry
    end
  end
end
