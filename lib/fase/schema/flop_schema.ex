defmodule Fase.Schema.FlopSchema do
  @moduledoc false

  use Fase.Internal.Types, include: [:schema_options]

  alias Fase.Filter
  alias Fase.Internal.Constants

  @default_fields [
    source: [
      ecto_type: :string
    ],
    text: [
      ecto_type: :string
    ]
  ]
  @default_filterable_fields Keyword.keys(@default_fields)

  @spec create_flop_custom_fields_option(schema_options()) :: Keyword.t()
  def create_flop_custom_fields_option(options) do
    %{fields: fields, data_fields: data_fields, facet_fields: facet_fields} =
      options
      |> Keyword.get_values(:sources)
      |> List.flatten()
      |> Enum.reduce(
        %{fields: [@default_fields], data_fields: [], facet_fields: []},
        fn {_source, source_options}, acc ->
          fields = Keyword.get_values(source_options, :fields) |> List.flatten()

          data_fields =
            Keyword.get_values(source_options, :data_fields)
            |> List.flatten()

          facet_fields =
            Keyword.get_values(source_options, :facet_fields)
            |> List.flatten()
            |> Enum.reduce([], fn
              {name, options}, acc when name == :hierarchies ->
                Enum.reduce(options, acc, fn {level_name, level_options},
                                             acc_1 ->
                  level_options = level_options ++ [hierarchy: true]

                  [{level_name, level_options} | acc_1]
                end)

              {name, options}, acc ->
                [{name, options} | acc]

              name, acc ->
                [{name, []} | acc]
            end)

          %{
            fields: Enum.concat(acc.fields, fields),
            data_fields: Enum.concat(acc.data_fields, data_fields),
            facet_fields: Enum.concat(acc.facet_fields, facet_fields)
          }
        end
      )
      |> Map.update(:fields, [], fn existing -> clean_up_fields(existing) end)
      |> Map.update(:data_fields, [], fn existing ->
        clean_up_fields(existing)
      end)
      |> Map.update(:facet_fields, [], fn existing ->
        clean_up_fields(existing)
      end)

    module = Keyword.get(options, :module)

    Enum.concat(
      create_filter_field_options(fields, data_fields, module),
      create_facet_search_field_options(
        facet_fields,
        fields,
        data_fields,
        module
      )
    )
  end

  defp clean_up_fields(fields),
    do:
      fields
      |> List.flatten()
      |> Enum.uniq()

  defp create_filter_field_options(fields, data_fields, module) do
    fields
    |> Enum.reduce([], fn {column_name, column_options}, acc ->
      ecto_type =
        get_ecto_type_from_data_fields(data_fields, column_name) ||
          Keyword.get(column_options, :ecto_type)

      operators = column_options[:operators]

      allowed_operators_option =
        if operators, do: [operators: operators], else: []

      custom_field =
        {column_name,
         [
           filter:
             {Filter, :filter,
              [
                ecto_type: ecto_type,
                module: module
              ]},
           ecto_type: ecto_type
         ] ++ allowed_operators_option}

      [custom_field | acc]
    end)
  end

  defp get_ecto_type_from_data_fields(data_fields, column_name) do
    Enum.find_value(data_fields, fn
      {name, opts} when name == column_name -> Keyword.get(opts, :ecto_type)
      _ -> nil
    end)
  end

  # Skip warning: Atoms are generated at compile time.
  # sobelow_skip ["DOS.BinToAtom"]
  defp create_facet_search_field_options(
         facet_fields,
         fields,
         data_fields,
         module
       ) do
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
          ecto_type =
            get_ecto_type_from_data_fields(data_fields, column_name) ||
              Keyword.get(field_options, :ecto_type, :integer)

          {column_name, ecto_type}
        end

      is_hierarchy_facet = Keyword.get(column_options, :hierarchy, false)

      # source_is_array: data is stored in JSON as array
      {facet_ecto_type, source_is_array} =
        normalize_facet_field_ecto_type(ecto_type, is_hierarchy_facet)

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
                is_range_facet: is_range_facet,
                is_hierarchy_facet: is_hierarchy_facet,
                module: module
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
      Enum.concat(
        acc,
        create_sortable_field_data(source_options, custom_fields)
      )
    end)
    |> Enum.uniq()
  end

  # Skip warning: Atoms are generated at compile time.
  # sobelow_skip ["DOS.BinToAtom"]
  defp create_sortable_field_data(source_options, custom_fields) do
    Keyword.get_values(source_options, :sort_fields)
    |> List.flatten()
    |> Enum.map(fn sort_field ->
      {name, options} =
        case sort_field do
          {name, options} when is_list(options) -> {name, options}
          {name, _} -> {name, []}
          name -> {name, []}
        end

      field_data = Keyword.get(custom_fields, name)

      ecto_type_from_sort_field = Keyword.get(options, :ecto_type)

      ecto_type =
        cond do
          not is_nil(ecto_type_from_sort_field) -> ecto_type_from_sort_field
          not is_nil(field_data) -> Keyword.get(field_data, :ecto_type)
          true -> :string
        end

      %{
        name: :"#{Constants.sort_field_prefix()}#{name}",
        ecto_type: ecto_type,
        transforms: Keyword.get(options, :transforms)
      }
    end)
  end

  defp normalize_facet_field_ecto_type(
         {:array, _type} = _ecto_type,
         is_hierarchy_facet
       )
       when is_hierarchy_facet,
       do: {{:array, :string}, true}

  defp normalize_facet_field_ecto_type(
         {:array, type} = _ecto_type,
         _is_hierarchy_facet
       ),
       do: {{:array, type}, true}

  defp normalize_facet_field_ecto_type(_type, is_hierarchy_facet)
       when is_hierarchy_facet,
       do: {{:array, :string}, false}

  defp normalize_facet_field_ecto_type(type, _is_hierarchy_facet),
    do: {{:array, type}, false}
end
