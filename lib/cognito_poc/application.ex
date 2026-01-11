defmodule CognitoPoc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CognitoPoc.AwsClient,
      {Plug.Cowboy, scheme: :http, plug: CognitoPocWeb.Router, options: [port: 4000]}
    ]

    :hackney_pool.start_pool(:legacy_pool, timeout: 15_000, max_connections: 200)

    if Mix.env() != :test, do: IO.puts("App rodando em http://localhost:4000")

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CognitoPoc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
