defmodule FacetedSearch.Facet do
  @moduledoc """
  Facet struct containing field, type and a list of `FacetedSearch.FacetValue` structs.
  """

  @enforce_keys [:type, :field, :facet_values]
  defstruct type: nil, field: nil, facet_values: nil

  @type t() :: %__MODULE__{
          type: String.t(),
          field: atom(),
          facet_values: list(FacetedSearch.FacetValue)
        }
end
