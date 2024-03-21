defmodule Estructura.MixProject do
  use Mix.Project

  @app :estructura
  @version "1.3.3"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.12",
      compilers: compilers(Mix.env()),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() not in [:dev, :test],
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :ci,
        dialyzer: :ci,
        tests: :test,
        "coveralls.json": :test,
        "coveralls.html": :test,
        "hex.publish": :ci,
        "quality.ci": :ci
      ],
      releases: [],
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/dialyzer.plt"},
        plt_add_deps: :app_tree,
        plt_add_apps: [:mix],
        list_unused_filters: true,
        ignore_warnings: ".dialyzer/ignore.exs"
      ]
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:stream_data, "~> 0.5"},
      {:formulae, "~> 0.14", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:excoveralls, "~> 0.14", only: [:test, :ci], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test, :ci]},
      {:dialyxir, "~> 1.0", only: [:dev, :test, :ci], runtime: false},
      {:ex_doc, "~> 0.11", only: [:dev, :ci]}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp description do
    """
    Extensions for Elixir structures.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w|lib stuff .formatter.exs .dialyzer/ignore.exs mix.exs README* LICENSE|,
      maintainers: ["Aleksei Matiushkin"],
      licenses: ["Kantox LTD"],
      links: %{
        "GitHub" => "https://github.com/am-kantox/#{@app}",
        "Docs" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "Estructura",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/#{@app}",
      logo: "stuff/#{@app}-48x48.png",
      source_url: "https://github.com/am-kantox/#{@app}",
      extras: ~w[README.md],
      groups_for_modules: [
        # Estructura,
        # Estructura.Nested,
        # Estructura.Aston,
        Protocols: [
          Estructura.Flattenable,
          Estructura.Transformer
        ],
        Generators: [
          Estructura.StreamData
        ],
        Lazy: [
          Estructura.Lazy,
          Estructura.LazyMap
        ],
        Coercers: [
          Estructura.Coercer,
          Estructura.Coercers.Date,
          Estructura.Coercers.Datetime,
          Estructura.Coercers.Integer,
          Estructura.Coercers.Float,
          Estructura.Coercers.Time,
          Estructura.Coercers.NullableDate,
          Estructura.Coercers.NullableDatetime,
          Estructura.Coercers.NullableFloat,
          Estructura.Coercers.NullableInteger,
          Estructura.Coercers.NullableTime
        ],
        Internals: [
          Estructura.Config
        ],
        Examples: [
          Estructura.Full,
          Estructura.User
        ]
      ]
    ]
  end

  defp elixirc_paths(:ci), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(_), do: Mix.compilers()
end
