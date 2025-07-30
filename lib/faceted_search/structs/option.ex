defmodule FacetedSearch.Option do
  @moduledoc """
  A discrete, filterable option associated with a specific facet, representing one possible value that occurs in the dataset.
  """

  @enforce_keys [:value, :label, :count, :selected]
  defstruct value: nil, label: nil, count: nil, selected: nil

  @type t() :: %__MODULE__{
          value: term(),
          label: String.t() | term(),
          count: integer(),
          selected: boolean()
        }
end
