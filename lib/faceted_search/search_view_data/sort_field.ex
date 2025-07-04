defmodule FacetedSearch.SortField do
  @moduledoc """
  Properties of a sort field that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, cast: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          cast: :integer | :float | :text | nil
        }
end
