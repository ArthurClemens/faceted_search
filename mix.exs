defmodule FacetedSearch.MixProject do
  use Mix.Project

  @source_url "https://github.com/ArthurClemens/faceted_search"
  @adapters ~w(postgres)

  def project do
    [
      app: :faceted_search,
      name: "FacetedSearch",
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: [plt_add_apps: [:mix]],
      test_paths: get_test_paths(System.get_env("ECTO_ADAPTER")),
      preferred_cli_env: [
        "ecto.create": :test,
        "ecto.drop": :test,
        "ecto.migrate": :test,
        "ecto.reset": :test,
        "test.all": :test,
        "test.adapters": :test,
        dialyzer: :test
      ],
      consolidate_protocols: Mix.env() != :test
    ]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/support"]

  defp elixirc_paths(_), do: ["lib"]

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
      {:ex_machina, "~> 2.8.0", only: :test},
      {:flop, "~> 0.26"},
      {:nimble_options, "~> 1.1"},
      {:postgrex, "~> 0.20"},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "documentation/schema_configuration.md",
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

  defp aliases do
    [
      "test.all": ["test", "test.adapters"],
      "test.postgres": &test_adapters(["postgres"], &1),
      "test.adapters": &test_adapters/1,
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

  defp test_adapters(adapters \\ @adapters, args) do
    for adapter <- adapters do
      IO.puts("==> Running tests for ECTO_ADAPTER=#{adapter} mix test")

      {_, res} =
        System.cmd(
          "mix",
          ["test", ansi_option() | args],
          into: IO.binstream(:stdio, :line),
          env: [{"ECTO_ADAPTER", adapter}]
        )

      if res > 0 do
        System.at_exit(fn _ -> exit({:shutdown, 1}) end)
      end
    end
  end

  defp ansi_option do
    if IO.ANSI.enabled?(), do: "--color", else: "--no-color"
  end

  defp get_test_paths(adapter) when adapter in @adapters,
    do: ["test/adapters/ecto/#{adapter}"]

  defp get_test_paths(nil), do: ["test/base"]

  defp get_test_paths(adapter) do
    raise """
    unknown Ecto adapter

    Expected ECTO_ADAPTER to be one of: #{inspect(@adapters)}

    Got: #{inspect(adapter)}
    """
  end
end
