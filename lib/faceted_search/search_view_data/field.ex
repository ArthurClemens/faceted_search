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
            prefix: nil,
            name: nil,
            ecto_type: nil,
            binding: nil,
            column: nil

  @type t() :: %__MODULE__{
          # required
          table_name: atom(),
          name: atom(),
          # optional
          ecto_type: ecto_type() | nil,
          binding: atom() | nil,
          prefix: String.t() | nil,
          column: atom() | nil
        }

  def new(name, field_options, table_name, prefix) do
    column = Keyword.get(field_options, :column, name)

    struct(
      __MODULE__,
      field_options
      |> Keyword.put(:name, name)
      |> Keyword.put(:column, column)
      |> Keyword.put(:table_name, table_name)
      |> Keyword.put(:prefix, prefix)
    )
  end
end
