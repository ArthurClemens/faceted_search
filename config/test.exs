import Config

config :flop,
  ecto_repos: [FacetedSearch.Test.Repo],
  repo: FacetedSearch.Test.Repo

config :logger, level: :warning

config :faceted_search, mode: :test
