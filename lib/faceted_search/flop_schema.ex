defmodule FacetedSearch.FlopSchema do
  @moduledoc false

  use FacetedSearch.Types, include: [:schema_options]

  alias FacetedSearch.Constants
  alias FacetedSearch.Filter

  @default_filterable_fields [:source, :text]

  @spec create_flop_custom_fields_option(schema_options()) :: Keyword.t()
  def create_flop_custom_fields_option(options) do
    %{fields: fields, facet_fields: facet_fields} =
      options
      |> Keyword.get_values(:sources)
      |> List.flatten()
      |> Enum.reduce(%{fields: [], facet_fields: []}, fn {_source, source_options}, acc ->
        fields = Keyword.get_values(source_options, :fields) |> List.flatten()

        facet_fields =
          Keyword.get_values(source_options, :facet_fields)
          |> List.flatten()
          |> Enum.map(fn
            {name, options} -> {name, options}
            name -> {name, []}
          end)

        %{
          fields: Enum.concat(acc.fields, fields),
          facet_fields: Enum.concat(acc.facet_fields, facet_fields)
        }
      end)
      |> Map.update(:fields, [], fn existing -> clean_up_fields(existing) end)
      |> Map.update(:facet_fields, [], fn existing -> clean_up_fields(existing) end)

    Enum.concat(
      create_filter_field_options(fields),
      create_facet_search_field_options(facet_fields, fields)
    )
  end

  defp clean_up_fields(fields),
    do:
      fields
      |> List.flatten()
      |> Enum.uniq()

  defp create_filter_field_options(fields) do
    fields
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
  defp create_facet_search_field_options(facet_fields, fields) do
    facet_fields
    |> Enum.reduce([], fn {column_name, column_options}, acc ->
      field_options = Keyword.get(fields, column_name, [])

      # Atoms are generated at compile time
      prefix = Constants.facet_search_field_prefix()
      facet_column_name = :"#{prefix}#{column_name}"

      is_range_facet =
        cond do
          Keyword.has_key?(column_options, :number_range_bounds) -> true
          Keyword.has_key?(column_options, :date_range_bounds) -> true
          true -> false
        end

      # field_reference is used in Filter to get the field name in the JSON data
      # For ranges/buckets, we use the facet_ prefix; for other facet fields the original field name
      {field_reference, ecto_type} =
        if is_range_facet do
          # Atoms are generated at compile time
          range_facet_column_name = :"#{column_name}"
          {range_facet_column_name, :integer}
        else
          ecto_type = Keyword.get(field_options, :ecto_type, :integer)
          {column_name, ecto_type}
        end

      # source_is_array: data is stored in JSON as array
      {facet_ecto_type, source_is_array} = normalize_facet_field_ecto_type(ecto_type)

      facet_field =
        {facet_column_name,
         [
           filter:
             {Filter, :filter,
              [
                ecto_type: facet_ecto_type,
                source_is_array: source_is_array,
                field_reference: field_reference,
                is_facet_search: true,
                is_range_facet: is_range_facet
              ]},
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
          {name, _} -> {name, nil}
          name -> {name, nil}
        end

      field_data = Keyword.get(custom_fields, name)
      ecto_type = if field_data, do: Keyword.get(field_data, :ecto_type), else: :string

      %{
        name: :"sort_#{name}",
        ecto_type: ecto_type,
        cast: cast
      }
    end)
  end

  defp normalize_facet_field_ecto_type({:array, type} = _ecto_type), do: {{:array, type}, true}
  defp normalize_facet_field_ecto_type(type), do: {{:array, type}, false}
end
