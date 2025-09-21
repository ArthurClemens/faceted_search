defmodule Fase.SortField do
  @moduledoc """
  Properties of a sort field that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, transforms: nil, ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          transforms: list(String.t()) | nil,
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
        transforms: Keyword.get(options, :transforms),
        ecto_type: Keyword.get(options, :ecto_type)
      }
    )
  end
end
