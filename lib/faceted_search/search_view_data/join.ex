defmodule FacetedSearch.Join do
  @moduledoc """
  Table join data extracted from the schema.
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
