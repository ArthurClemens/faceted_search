import Config

config :flop,
  ecto_repos: [Fase.Test.Repo],
  repo: Fase.Test.Repo

config :logger, level: :warning
