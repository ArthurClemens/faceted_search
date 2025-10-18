import Config

config :flop,
  ecto_repos: [MyApp.Repo],
  repo: MyApp.Repo

config :logger, level: :warning
