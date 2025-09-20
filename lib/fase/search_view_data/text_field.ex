defmodule Fase.TextField do
  @moduledoc """
  Properties of a text field that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, operations: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          operations: list(String.t()) | nil
        }

  def new(field_options) do
    {name, operations} =
      case field_options do
        {name, [operations: operations]} -> {name, operations}
        name -> {name, nil}
      end

    struct(
      __MODULE__,
      %{
        name: name,
        operations: operations
      }
    )
  end
end
