defmodule Fase.SortField do
  @moduledoc """
  Properties of a sort field that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, operations: nil, ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          operations: list(String.t()) | nil,
          ecto_type: atom() | nil
        }

  def new(field_options) do
    {name, options} =
      case field_options do
        {name, options} when is_list(options) -> {name, options}
        name -> {name, []}
      end

    struct(
      __MODULE__,
      %{
        name: name,
        operations: Keyword.get(options, :operations),
        ecto_type: Keyword.get(options, :ecto_type)
      }
    )
  end
end
