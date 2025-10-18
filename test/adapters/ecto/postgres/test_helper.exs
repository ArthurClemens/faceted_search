Application.put_env(:my_app, MyApp.Repo,
  username: "postgres",
  password: "postgres",
  database: "fase_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end

defmodule Fase.Test.Integration.Case do
  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    :ok = Sandbox.checkout(MyApp.Repo)
  end

  setup do
    %{ecto_adapter: :postgres}
  end
end

Code.require_file("migration.exs", __DIR__)

{:ok, _} =
  Ecto.Adapters.Postgres.ensure_all_started(
    MyApp.Repo.config(),
    :temporary
  )

Ecto.Adapters.Postgres.storage_down(MyApp.Repo.config())
Ecto.Adapters.Postgres.storage_up(MyApp.Repo.config())

{:ok, _pid} = MyApp.Repo.start_link()

Ecto.Migrator.up(
  MyApp.Repo,
  0,
  MyApp.Repo.Postgres.Migration,
  log: true
)

Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :auto)

{:ok, _} = Application.ensure_all_started(:ex_machina)
ExUnit.start()
