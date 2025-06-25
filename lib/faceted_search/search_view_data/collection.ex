defmodule FacetedSearch.Collection do
  @moduledoc """
  Data extracted from the schema.
  """

  alias FacetedSearch.Field
  alias FacetedSearch.Join
  alias FacetedSearch.Scope

  @enforce_keys [
    :table_name
  ]

  defstruct table_name: nil,
            scopes: nil,
            prefix: nil,
            fields: nil,
            joins: nil,
            data_fields: nil,
            text_fields: nil,
            facet_fields: nil

  @type t() :: %__MODULE__{
          # required
          table_name: atom(),
          # optional
          facet_fields: list(atom()) | nil,
          fields: list(Field.t()) | nil,
          data_fields: list(atom()) | nil,
          joins: list(Join.t()) | nil,
          prefix: String.t() | nil,
          scopes: list(Scope.t()) | nil,
          text_fields: list(atom()) | nil
        }

  @spec new({atom(), Keyword.t()}, atom()) :: t()

  def new({table_name, options}, module) do
    %__MODULE__{
      table_name: table_name,
      scopes: Keyword.get(options, :scopes) |> collect_scopes(module),
      prefix: Keyword.get(options, :prefix),
      fields: Keyword.get(options, :fields) |> collect_fields(table_name),
      joins: Keyword.get(options, :joins) |> collect_joins(),
      data_fields: Keyword.get(options, :data_fields),
      text_fields: Keyword.get(options, :text_fields),
      facet_fields: Keyword.get(options, :facet_fields)
    }
  end

  defp collect_joins(joins) when is_list(joins) do
    Enum.map(joins, &create_join_entry/1)
  end

  defp collect_joins(_joins), do: nil

  defp create_join_entry(join_options) do
    struct(Join, join_options)
  end

  defp collect_fields(fields, table_name) when is_list(fields) and fields != [] do
    Enum.map(fields, &create_field_entry(table_name, &1))
  end

  defp collect_fields(_fields, _table_name), do: nil

  defp create_field_entry(table_name, {name, field_options}) do
    struct(
      Field,
      field_options
      |> Keyword.put(:name, name)
      |> Keyword.put(:table_name, table_name)
    )
  end

  defp collect_scopes(scopes, module) when is_list(scopes) and scopes != [] do
    Enum.map(scopes, &create_scope_entry(module, &1))
  end

  defp collect_scopes(_scopes, _module), do: nil

  defp create_scope_entry(module, scope_key) do
    struct(Scope, %{key: scope_key, module: module})
  end
end
