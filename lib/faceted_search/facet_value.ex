defmodule FacetedSearch.FacetValue do
  @moduledoc """
  A discrete, filterable option associated with a specific facet, representing one possible value that occurs in the dataset.
  """

  @enforce_keys [:value, :count, :selected]
  defstruct value: nil, count: nil, selected: nil

  @type t() :: %__MODULE__{
          value: term(),
          count: integer(),
          selected: boolean()
        }
end
