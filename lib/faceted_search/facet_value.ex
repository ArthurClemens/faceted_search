defmodule FacetedSearch.FacetValue do
  @moduledoc """
  Facet value struct.
  """

  @enforce_keys [:value, :count, :selected]
  defstruct value: nil, count: nil, selected: nil

  @type t() :: %__MODULE__{
          value: term(),
          count: integer(),
          selected: boolean()
        }
end
