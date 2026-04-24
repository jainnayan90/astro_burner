defmodule AstroBurner.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AstroBurnerWeb.Telemetry,
      AstroBurner.Repo,
      {DNSCluster, query: Application.get_env(:astro_burner, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AstroBurner.PubSub},
      # Start a worker by calling: AstroBurner.Worker.start_link(arg)
      # {AstroBurner.Worker, arg},
      # Start to serve requests, typically the last entry
      AstroBurnerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AstroBurner.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AstroBurnerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
