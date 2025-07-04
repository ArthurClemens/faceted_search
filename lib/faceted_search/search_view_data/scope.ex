defmodule FacetedSearch.Scope do
  @moduledoc """
  Definition for the `scope_by` callback.
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
