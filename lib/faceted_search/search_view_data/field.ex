defmodule FacetedSearch.Field do
  @moduledoc """
  Properties of a database field from the source table or from a joined table that is included in search view generation.
  """

  @type ecto_type ::
          Ecto.Type.t()
          | {:from_schema, module, atom}
          | {:ecto_enum, [atom] | keyword}

  @enforce_keys [
    :table_name,
    :name
  ]

  defstruct table_name: nil,
            name: nil,
            ecto_type: nil,
            binding: nil,
            field: nil

  @type t() :: %__MODULE__{
          # required
          table_name: atom(),
          name: atom(),
          # optional
          ecto_type: ecto_type() | nil,
          binding: atom() | nil,
          field: atom() | nil
        }
end
