defmodule FacetedSearch.FlopSchema do
  @moduledoc false

  use FacetedSearch.Types, include: [:schema_options]

  alias FacetedSearch.Filter

  @spec create_custom_fields_option(schema_options()) :: Keyword.t()
  def create_custom_fields_option(options) do
    table_options =
      options
      |> Keyword.get_values(:sources)
      |> List.flatten()
      |> Enum.reduce([], fn {_source, table_options}, acc ->
        fields = Keyword.get_values(table_options, :fields)
        Enum.concat(acc, fields)
      end)
      |> List.flatten()
      |> Enum.uniq()

    Enum.concat(
      create_filter_field_options(table_options),
      create_facet_search_field_options(table_options)
    )
  end

  defp create_filter_field_options(table_options) do
    table_options
    |> Enum.reduce([], fn {column_name, column_options}, acc ->
      ecto_type = Keyword.get(column_options, :ecto_type)
      filter = Keyword.get(column_options, :filter)

      operators = column_options[:operators]
      allowed_operators_option = if operators, do: [operators: operators], else: []

      custom_field =
        {column_name,
         [
           filter: filter || {Filter, :filter, [ecto_type: ecto_type]},
           ecto_type: ecto_type
         ] ++ allowed_operators_option}

      [custom_field | acc]
    end)
  end

  defp create_facet_search_field_options(table_options) do
    table_options
    |> Enum.reduce([], fn {column_name, column_options}, acc ->
      ecto_type = Keyword.get(column_options, :ecto_type)

      # Atoms are generated at compile time
      facet_column_name = :"#{Filter.facet_search_field_prefix()}#{column_name}"
      # source_is_array: data is stored in JSON as array
      {facet_ecto_type, source_is_array} = normalize_facet_field_ecto_type(ecto_type)

      facet_field =
        {facet_column_name,
         [
           filter:
             {Filter, :filter, [ecto_type: facet_ecto_type, source_is_array: source_is_array]},
           ecto_type: facet_ecto_type
         ]}

      [facet_field | acc]
    end)
  end

  @default_filterable_fields [:source, :text]

  @spec create_filterable_fields_option(Keyword.t()) :: Keyword.t()
  def create_filterable_fields_option(custom_fields_option) do
    Enum.uniq(@default_filterable_fields ++ Keyword.keys(custom_fields_option))
  end

  @spec create_sortable_fields(Keyword.t(), Keyword.t()) :: Keyword.t()
  def create_sortable_fields(options, custom_fields) do
    options
    |> Keyword.get_values(:sources)
    |> List.flatten()
    |> Enum.reduce([], fn {_source, table_options}, acc ->
      sort_fields =
        Keyword.get_values(table_options, :sort_fields)
        |> List.flatten()
        |> Enum.map(fn sort_field ->
          %{
            name: :"sort_#{sort_field}",
            ecto_type: Keyword.get(custom_fields, sort_field) |> Keyword.get(:ecto_type)
          }
        end)

      Enum.concat(acc, sort_fields)
    end)
    |> Enum.uniq()
  end

  defp normalize_facet_field_ecto_type({:array, type} = _ecto_type), do: {{:array, type}, true}
  defp normalize_facet_field_ecto_type(type), do: {{:array, type}, false}
end
