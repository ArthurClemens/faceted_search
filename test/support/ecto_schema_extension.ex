defmodule FacetedSearch.Test.EctoSchemaExtension do
  @moduledoc """
  Macro used to employ a uuid for both primary and foreign keys.
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
