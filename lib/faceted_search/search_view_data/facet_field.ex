defmodule FacetedSearch.FacetField do
  @moduledoc """
  Properties of a facet field that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, label_field: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          label_field: atom() | nil
        }

  def new(field_options) do
    {name, label_field} =
      case field_options do
        {name, [label: label_field]} -> {name, label_field}
        name -> {name, nil}
      end

    struct(
      __MODULE__,
      %{
        name: name,
        label_field: label_field
      }
    )
  end
end
