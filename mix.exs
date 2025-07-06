defmodule FacetedSearch.MixProject do
  use Mix.Project

  @source_url "https://github.com/ArthurClemens/faceted_search"

  def project do
    [
      app: :faceted_search,
      name: "FacetedSearch",
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ecto_sql, "~> 3.12"},
      {:ex_doc, "~> 0.38.0", only: :dev, runtime: false},
      {:flop, "~> 0.22"},
      {:nimble_options, "~> 1.1"},
      {:postgrex, "~> 0.20"},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      assets: %{"documentation/assets" => "assets"},
      before_closing_head_tag: &docs_before_closing_head_tag/1
    ]
  end

  defp docs_before_closing_head_tag(:html) do
    ~s{<link rel="stylesheet" href="assets/doc.css">}
  end

  defp docs_before_closing_head_tag(_), do: ""

  defp aliases do
    [
      qa: [
        "typecheck",
        "deps.clean --unlock --unused",
        "format",
        "format --check-formatted",
        "compile",
        "docs",
        "sobelow --config",
        "credo --strict"
      ],
      typecheck: "dialyzer --format dialyzer",
      "typecheck.gen": "dialyzer --format ignore_file_strict"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp description do
    "Faceted search with Flop."
  end
end
