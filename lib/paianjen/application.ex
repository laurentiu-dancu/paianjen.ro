defmodule Paianjen.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PaianjenWeb.Telemetry,
      Paianjen.Repo,
      {DNSCluster, query: Application.get_env(:paianjen, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Paianjen.PubSub},
      {Finch, name: Paianjen.Finch},
      PaianjenWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Paianjen.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PaianjenWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
