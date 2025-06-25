defmodule FacetedSearch.Scope do
  @moduledoc """
  Scope data.
  """

  @enforce_keys [
    :key,
    :module
  ]

  defstruct key: nil,
            module: nil

  @type t() :: %__MODULE__{
          # required
          key: atom(),
          module: module()
        }
end
