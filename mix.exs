defmodule Pinchflat.MixProject do
  use Mix.Project

  def project do
    [
      app: :pinchflat,
      version: "2025.6.6",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: System.get_env("EX_CHECK") == "1"],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [
        check: :test,
        credo: :test
      ],
      test_coverage: [
        ignore_modules: [
          Pinchflat.HTTP.HTTPClient,
          PinchflatWeb.Layouts,
          Pinchflat.DataCase,
          Pinchflat.Release,
          ~r/Fixtures/,
          ~r/HTML$/
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Pinchflat.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto, "~> 3.12.3"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:ecto_sqlite3_extras, "~> 1.2.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:floki, ">= 0.36.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.18"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2"},
      {:plug_cowboy, "~> 2.5"},
      {:oban, "~> 2.17"},
      {:nimble_parsec, "~> 1.4"},
      # See: https://github.com/bitwalker/timex/issues/778
      {:timex, git: "https://github.com/bitwalker/timex.git", ref: "cc649c7a586f1266b17d57aff3c6eb1a56116ca2"},
      {:prom_ex, "~> 1.11.0"},
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.7.7", only: [:dev, :test], runtime: false},
      {:credo_naming, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16.0", only: [:dev, :test], runtime: false},
      {:faker, "~> 0.17", only: :test},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      check: "check --config=tooling/.check.exs",
      credo: "credo --config-file=tooling/.credo.exs",
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      "ecto.migrate": [
        "ecto.migrate",
        ~s(cmd [ -z "$MIX_ENV" ] && yarn run create-erd || echo "No ERD generated")
      ],
      "ecto.rollback": [
        "ecto.rollback",
        ~s(cmd [ -z "$MIX_ENV" ] && yarn run create-erd || echo "No ERD generated")
      ],
      "version.bump": "cmd ./tooling/version_bump.sh"
    ]
  end
end
