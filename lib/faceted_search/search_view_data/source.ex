defmodule FacetedSearch.Source do
  @moduledoc """
  Part of the `FacetedSearch.SearchViewDescription`.
  """

  alias FacetedSearch.DataField
  alias FacetedSearch.FacetField
  alias FacetedSearch.Field
  alias FacetedSearch.Join
  alias FacetedSearch.Scope
  alias FacetedSearch.SortField

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
            facet_fields: nil,
            sort_fields: nil

  @type t() :: %__MODULE__{
          # required
          table_name: atom(),
          # optional
          prefix: String.t() | nil,
          scopes: list(Scope.t()) | nil,
          joins: list(Join.t()) | nil,
          fields: list(Field.t()) | nil,
          data_fields: list(atom()) | nil,
          text_fields: list(atom()) | nil,
          facet_fields: list(FacetField.t()) | nil,
          sort_fields: list(SortField.t()) | nil
        }

  @spec new({atom(), Keyword.t()}, atom()) :: t()

  def new({table_name, options}, module) do
    %__MODULE__{
      table_name: table_name,
      prefix: Keyword.get(options, :prefix),
      scopes: Keyword.get(options, :scope_keys) |> collect_scopes(module),
      joins: Keyword.get(options, :joins) |> collect_joins(),
      fields: Keyword.get(options, :fields) |> collect_fields(table_name),
      data_fields: Keyword.get(options, :data_fields) |> collect_data_fields(),
      text_fields: Keyword.get(options, :text_fields),
      facet_fields: Keyword.get(options, :facet_fields) |> collect_facet_fields(),
      sort_fields: Keyword.get(options, :sort_fields) |> collect_sort_fields()
    }
  end

  defp collect_joins(joins) when is_list(joins) do
    Enum.map(joins, fn {name, options} -> Join.new(name, options) end)
  end

  defp collect_joins(_joins), do: nil

  defp collect_fields(fields, table_name) when is_list(fields) and fields != [] do
    fields
    |> Enum.concat(default_fields())
    |> Enum.map(fn {name, field_options} -> Field.new(name, field_options, table_name) end)
  end

  defp collect_fields(_fields, _table_name), do: nil

  defp default_fields do
    [
      inserted_at: [ecto_type: :utc_datetime],
      updated_at: [ecto_type: :utc_datetime]
    ]
  end

  defp collect_data_fields(fields) when is_list(fields) and fields != [] do
    Enum.map(fields, fn
      {name, field_options} -> DataField.new(name, field_options)
      name -> DataField.new(name)
    end)
  end

  defp collect_data_fields(_fields), do: nil

  defp collect_scopes(scope_keys, module) when is_list(scope_keys) and scope_keys != [] do
    Enum.map(scope_keys, fn scope_key -> Scope.new(module, scope_key) end)
  end

  defp collect_scopes(_scope_keys, _module), do: nil

  defp collect_sort_fields(sort_fields) when is_list(sort_fields) and sort_fields != [] do
    Enum.map(sort_fields, fn field_options -> SortField.new(field_options) end)
  end

  defp collect_sort_fields(_sort_fields), do: nil

  defp collect_facet_fields(facet_fields) when is_list(facet_fields) and facet_fields != [] do
    {hierarchy_options, regular_options} =
      facet_fields
      |> Enum.split_with(fn
        {:hierarchies, _} -> true
        _ -> false
      end)

    regular_fields =
      Enum.map(regular_options, fn field_options -> FacetField.new(field_options) end)

    hierarchy_fields = create_hierarchy_fields(hierarchy_options)

    Enum.concat(regular_fields, hierarchy_fields)
  end

  defp collect_facet_fields(_facet_fields), do: nil

  defp create_hierarchy_fields(hierarchy_options) do
    Enum.reduce(hierarchy_options, [], fn {:hierarchies, hierarchies}, acc ->
      path_lookup =
        Enum.reduce(hierarchies, %{}, fn {name, opts}, acc ->
          Map.put(acc, Keyword.get(opts, :path), name)
        end)

      Enum.reduce(hierarchies, acc, fn {name, hierarchy_opts}, acc_1 ->
        opts =
          hierarchy_opts
          |> Keyword.put(:hierarchy, true)
          |> maybe_set_hierarchy_parent(path_lookup)

        [FacetField.new({name, opts}) | acc_1]
      end)
    end)
  end

  defp maybe_set_hierarchy_parent(opts, path_lookup) do
    if Keyword.get(opts, :parent) do
      opts
    else
      path = Keyword.get(opts, :path)

      parent_path_to_match =
        path
        |> Enum.reverse()
        |> tl()
        |> Enum.reverse()

      parent = path_lookup[parent_path_to_match]
      Keyword.put(opts, :parent, parent)
    end
  end
end
