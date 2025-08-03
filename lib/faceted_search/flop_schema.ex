defmodule FacetedSearch.FlopSchema do
  @moduledoc false

  use FacetedSearch.Types, include: [:schema_options]

  alias FacetedSearch.Constants
  alias FacetedSearch.Filter

  @default_filterable_fields [:source, :text]

  @spec create_custom_fields_option(schema_options()) :: Keyword.t()
  def create_custom_fields_option(options) do
    source_options =
      options
      |> Keyword.get_values(:sources)
      |> List.flatten()
      |> Enum.reduce([], fn {_source, source_options}, acc ->
        fields = Keyword.get_values(source_options, :fields)
        Enum.concat(acc, fields)
      end)
      |> List.flatten()
      |> Enum.uniq()

    Enum.concat(
      create_filter_field_options(source_options),
      create_facet_search_field_options(source_options)
    )
  end

  defp create_filter_field_options(source_options) do
    source_options
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

  # Skip warning: Atoms are generated at compile time.
  # sobelow_skip ["DOS.BinToAtom"]
  defp create_facet_search_field_options(source_options) do
    source_options
    |> Enum.reduce([], fn {column_name, column_options}, acc ->
      ecto_type = Keyword.get(column_options, :ecto_type)

      # Atoms are generated at compile time
      facet_column_name = :"#{Constants.facet_search_field_prefix()}#{column_name}"
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

  @spec create_filterable_fields_option(Keyword.t()) :: Keyword.t()
  def create_filterable_fields_option(custom_fields_option) do
    Enum.uniq(@default_filterable_fields ++ Keyword.keys(custom_fields_option))
  end

  # Skip warning: Atoms are generated at compile time.
  # sobelow_skip ["DOS.BinToAtom"]
  @spec create_sortable_fields(Keyword.t(), Keyword.t()) :: Keyword.t()
  def create_sortable_fields(options, custom_fields) do
    options
    |> Keyword.get_values(:sources)
    |> List.flatten()
    |> Enum.reduce([], fn {_source, source_options}, acc ->
      Enum.concat(acc, create_sortable_field_data(source_options, custom_fields))
    end)
    |> Enum.uniq()
  end

  # Skip warning: Atoms are generated at compile time.
  # sobelow_skip ["DOS.BinToAtom"]
  defp create_sortable_field_data(source_options, custom_fields) do
    Keyword.get_values(source_options, :sort_fields)
    |> List.flatten()
    |> Enum.map(fn sort_field ->
      {name, cast} =
        case sort_field do
          {name, [cast: cast]} -> {name, cast}
          name -> {name, nil}
        end

      %{
        name: :"sort_#{name}",
        ecto_type: Keyword.get(custom_fields, name) |> Keyword.get(:ecto_type),
        cast: cast
      }
    end)
  end

  defp normalize_facet_field_ecto_type({:array, type} = _ecto_type), do: {{:array, type}, true}
  defp normalize_facet_field_ecto_type(type), do: {{:array, type}, false}
end
