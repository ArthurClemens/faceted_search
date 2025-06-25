defmodule FacetedSearch.Field do
  @moduledoc """
  Field data extracted from the schema.
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
