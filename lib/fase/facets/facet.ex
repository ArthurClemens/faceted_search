defmodule Fase.Facet do
  @moduledoc """
  A structured, filterable field in the search interface, used to group and refine search results by distinct values.
  """

  @enforce_keys [:field, :label, :options]
  defstruct field: nil, label: nil, options: nil, parent: nil

  @type t() :: %__MODULE__{
          field: atom(),
          label: String.t(),
          options: list(Fase.Option),
          parent: atom() | nil
        }
end
