defmodule Fase.Test.MyApp.Role do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.Author

  schema "roles" do
    field :name, Ecto.Enum, values: [:author, :editor, :assistant]

    belongs_to :author, Author
  end
end
