defmodule Fase.MixProject do
  use Mix.Project

  @source_url "https://github.com/ArthurClemens/fase"
  @adapters ~w(pg)

  def project do
    [
      app: :fase,
      name: "Fase",
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: [plt_add_apps: [:mix]],
      test_paths: test_paths(System.get_env("ECTO_ADAPTER")),
      test_ignore_filters: ["test/adapters/ecto/postgres/migration.exs"],
      consolidate_protocols: Mix.env() != :test
    ]
  end

  def cli do
    [
      preferred_envs: [
        "ecto.create": :test,
        "ecto.drop": :test,
        "ecto.migrate": :test,
        "ecto.reset": :test,
        "test.all": :test,
        "test.adapters": :test,
        dialyzer: :test
      ]
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
      {:ecto_sql, "~> 3.13"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:flop, "~> 0.26"},
      {:nimble_options, "~> 1.1"},
      {:postgrex, "~> 0.22"},
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
      typecheck: "dialyzer --format dialyzer"
    ]
  end

  defp test_adapters(args) do
    for adapter <- @adapters, do: env_run(adapter, args)
  end

  defp env_run(adapter, args) do
    IO.puts("==> Running tests for ECTO_ADAPTER=#{adapter} mix test")

    mix_cmd_with_status_check(
      ["test", ansi_option() | args],
      env: [{"ECTO_ADAPTER", adapter}]
    )
  end

  defp ansi_option do
    if IO.ANSI.enabled?(), do: "--color", else: "--no-color"
  end

  defp mix_cmd_with_status_check(args, opts) do
    {_, res} =
      System.cmd("mix", args, [into: IO.binstream(:stdio, :line)] ++ opts)

    if res > 0 do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp test_paths(adapter) when adapter in @adapters do
    folder =
      case adapter do
        "pg" -> "postgres"
        adapter -> adapter
      end

    ["test/adapters/ecto/#{folder}"]
  end

  defp test_paths(nil), do: ["test/base"]
  defp test_paths(other), do: raise("unknown adapter #{inspect(other)}")
end
