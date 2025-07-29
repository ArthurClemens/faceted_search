defmodule FacetedSearch.Facet do
  @moduledoc """
  A structured, filterable field exposed in the search interface, used to group and refine search results by distinct values.
  """

  @enforce_keys [:type, :field, :facet_values]
  defstruct type: nil, field: nil, facet_values: nil

  @type t() :: %__MODULE__{
          type: String.t(),
          field: atom(),
          facet_values: list(FacetedSearch.FacetValue)
        }
end
