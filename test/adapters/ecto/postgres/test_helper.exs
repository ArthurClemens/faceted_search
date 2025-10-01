Application.put_env(:fase, Fase.Test.Repo,
  username: "postgres",
  password: "postgres",
  database: "fase_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule Fase.Test.Repo do
  use Ecto.Repo,
    otp_app: :fase,
    adapter: Ecto.Adapters.Postgres
end

defmodule Fase.Test.Integration.Case do
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(Fase.Test.Repo)
  end

  setup do
    %{ecto_adapter: :postgres}
  end
end

Code.require_file("migration.exs", __DIR__)

{:ok, _} =
  Ecto.Adapters.Postgres.ensure_all_started(
    Fase.Test.Repo.config(),
    :temporary
  )

Ecto.Adapters.Postgres.storage_down(Fase.Test.Repo.config())
Ecto.Adapters.Postgres.storage_up(Fase.Test.Repo.config())

{:ok, _pid} = Fase.Test.Repo.start_link()

Ecto.Migrator.up(
  Fase.Test.Repo,
  0,
  Fase.Test.Repo.Postgres.Migration,
  log: true
)

Ecto.Adapters.SQL.Sandbox.mode(Fase.Test.Repo, :auto)

{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start()
