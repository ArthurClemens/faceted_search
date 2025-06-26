defmodule FacetedSearch.Join do
  @moduledoc """
  Properties of a joined field that is included in the search view generation.
  """

  @enforce_keys [
    :table,
    :on
  ]

  defstruct table: nil, on: nil, as: nil, prefix: nil

  @type t() :: %__MODULE__{
          # required
          table: atom(),
          on: String.t(),
          # optional
          as: String.t() | nil,
          prefix: String.t() | nil
        }
end
