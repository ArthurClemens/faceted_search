Application.put_env(:faceted_search, :async_integration_tests, true)

Application.put_env(:faceted_search, FacetedSearch.Test.Repo,
  username: "postgres",
  password: "postgres",
  database: "faceted_search_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule FacetedSearch.Test.Repo do
  use Ecto.Repo,
    otp_app: :faceted_search,
    adapter: Ecto.Adapters.Postgres
end

defmodule FacetedSearch.Test.Integration.Case do
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(FacetedSearch.Test.Repo)
  end

  setup do
    %{ecto_adapter: :postgres}
  end
end

Code.require_file("migration.exs", __DIR__)

{:ok, _} =
  Ecto.Adapters.Postgres.ensure_all_started(
    FacetedSearch.Test.Repo.config(),
    :temporary
  )

Ecto.Adapters.Postgres.storage_down(FacetedSearch.Test.Repo.config())
Ecto.Adapters.Postgres.storage_up(FacetedSearch.Test.Repo.config())

{:ok, _pid} = FacetedSearch.Test.Repo.start_link()

Ecto.Migrator.up(
  FacetedSearch.Test.Repo,
  0,
  FacetedSearch.Test.Repo.Postgres.Migration,
  log: true
)

Ecto.Adapters.SQL.Sandbox.mode(FacetedSearch.Test.Repo, :manual)

{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start()
