defmodule Fase.TextField do
  @moduledoc """
  Properties of a text field that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, transforms: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          transforms: list(String.t()) | nil
        }

  def new(field_options) do
    {name, transforms} =
      case field_options do
        {name, [transforms: transforms]} -> {name, transforms}
        name -> {name, nil}
      end

    struct(
      __MODULE__,
      %{
        name: name,
        transforms: transforms
      }
    )
  end
end
