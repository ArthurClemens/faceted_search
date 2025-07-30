defmodule FacetedSearch.Facet do
  @moduledoc """
  A structured, filterable field exposed in the search interface, used to group and refine search results by distinct values.
  """

  @enforce_keys [:field, :options]
  defstruct field: nil, options: nil

  @type t() :: %__MODULE__{
          field: atom(),
          options: list(FacetedSearch.Option)
        }
end
