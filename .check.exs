[
  ## don't run tools concurrently
  # parallel: false,

  ## don't print info about skipped tools
  skipped: false,

  ## always run tools in fix mode (put it in ~/.check.exs locally, not in project config)
  fix: true,

  ## don't retry automatically even if last run resulted in failures
  # retry: false,

  ## list of tools (see `mix check` docs for a list of default curated tools)
  tools: [
    {:compiler, env: %{"MIX_ENV" => "test"}},
    {:formatter, env: %{"MIX_ENV" => "test"}},
    {:sobelow, "mix sobelow --config"},
    # TODO: delete these and replace them with builtin ex_unit and formatter tools
    # once Elixir 1.16.2 is released (see: https://github.com/karolsluszniak/ex_check/issues/41#issuecomment-1921390413)
    {:elixir_tests, "mix test"},
    {:elixir_formatting, "mix format --check-formatted", fix: "mix format"},
    {:prettier_formatting, "yarn run prettier . --check", fix: "yarn run prettier . --write"}

    ## curated tools may be disabled (e.g. the check for compilation warnings)
    # {:compiler, false},

    ## ...or have command & args adjusted (e.g. enable skip comments for sobelow)
    # {:sobelow, "mix sobelow --exit --skip"},

    ## ...or reordered (e.g. to see output from dialyzer before others)
    # {:dialyzer, order: -1},

    ## ...or reconfigured (e.g. disable parallel execution of ex_unit in umbrella)
    # {:ex_unit, umbrella: [parallel: false]},

    ## custom new tools may be added (Mix tasks or arbitrary commands)
    # {:my_task, "mix my_task", env: %{"MIX_ENV" => "prod"}},
    # {:my_tool, ["my_tool", "arg with spaces"]}
  ]
]
