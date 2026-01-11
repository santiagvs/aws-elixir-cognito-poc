defmodule CognitoPoc.MixProject do
  use Mix.Project

  def project do
    [
      app: :cognito_poc,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CognitoPoc.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:aws, "~> 1.0"},
      {:hackney, "~> 1.25"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end
