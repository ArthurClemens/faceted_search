defmodule FacetedSearch.NimbleSchema do
  @moduledoc false

  alias FacetedSearch.Constants
  alias FacetedSearch.Errors.InvalidOptionsError
  alias FacetedSearch.Errors.MissingCallbackError

  @raw_faceted_search_option_schema [
    module: [
      type: :atom,
      doc: "The schema module that calls `use FacetedSearch`. This is inserted automatically."
    ],
    sources: [
      type: :keyword_list,
      required: true,
      keys: [
        *: [
          type: :keyword_list,
          keys: [
            prefix: [
              type: :string
            ],
            joins: [
              type: :keyword_list,
              keys: [
                *: [
                  type: :keyword_list,
                  keys: [
                    table: [
                      type: :atom
                    ],
                    on: [
                      type: :string,
                      required: true
                    ],
                    prefix: [
                      type: :string
                    ]
                  ]
                ]
              ]
            ],
            fields: [
              type: :keyword_list,
              keys: [
                *: [
                  type: :keyword_list,
                  keys: [
                    binding: [type: :atom],
                    field: [type: :atom],
                    ecto_type: [
                      type: :any,
                      required: true
                    ],
                    filter: [
                      type: {:tuple, [:atom, :atom, :keyword_list]}
                    ],
                    operators: [
                      type: {:list, :atom}
                    ]
                  ]
                ]
              ]
            ],
            data_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :any]}]}}
            ],
            text_fields: [
              type: {:list, :atom}
            ],
            facet_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}}
            ],
            sort_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}}
            ],
            scope_keys: [
              type: {:list, :atom}
            ]
          ]
        ]
      ]
    ]
  ]

  @option_schema NimbleOptions.new!(@raw_faceted_search_option_schema)

  def option_schema, do: @option_schema

  def validate!(opts, module), do: validate!(opts, option_schema(), module)

  def validate!(opts, %NimbleOptions{} = schema, module) do
    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        validate_data_fields_options(opts)
        validate_text_fields_options(opts)
        validate_facet_fields_options(opts)
        validate_sort_fields_options(opts)
        validate_scope_callback(opts, opts[:module])

        opts

      {:error, err} ->
        raise InvalidOptionsError.from_nimble(err,
                module: module
              )
    end
  end

  defp validate_data_fields_options(opts) do
    option = :data_fields

    get_validation_entries(opts, option)
    |> Enum.map(fn %{source: source, entries: entries, field_keys: field_keys} ->
      entries
      |> Enum.filter(fn
        field when is_atom(field) ->
          if field in field_keys do
            field
          else
            raise_incorrect_reference(source, [option], field)
          end

        entry ->
          entry
      end)
      # credo:disable-for-next-line
      |> Enum.filter(fn
        {custom_data_option, custom_data} when is_list(custom_data) and custom_data != [] ->
          Enum.filter(custom_data, fn
            # Test field reference in custom data
            # required unless options `binding` and `field` are used
            field when is_atom(field) ->
              if field in field_keys do
                field
              else
                raise_incorrect_reference(source, [option, custom_data_option], field)
              end

            {field, key_value} = entry ->
              is_valid_binding_keys =
                Keyword.keys(key_value) |> Enum.all?(&(&1 in [:binding, :field]))

              cond do
                field not in field_keys and is_valid_binding_keys ->
                  entry

                field in field_keys ->
                  entry

                true ->
                  raise InvalidOptionsError.message(%{
                          source: source,
                          path: [option, custom_data_option],
                          key: field,
                          type: :incorrect_reference,
                          reason:
                            ~s(expected a name that is listed in `fields`, or "#{field}" to include options `binding` and `field`)
                        })
              end

            entry ->
              entry
          end)

        entry ->
          entry
      end)
      # credo:disable-for-next-line
      |> Enum.filter(fn
        {custom_data_option, custom_data} when is_list(custom_data) and custom_data != [] ->
          Enum.filter(custom_data, fn
            {field, [cast: value]} = entry ->
              if is_atom(value) do
                entry
              else
                raise InvalidOptionsError.message(%{
                        source: source,
                        path: [option, custom_data_option, field],
                        key: :cast,
                        type: :invalid_value,
                        reason: "expected an atom"
                      })
              end

            {field, [{key, _value}]} ->
              raise InvalidOptionsError.message(%{
                      source: source,
                      path: [option, custom_data_option, field],
                      key: key,
                      type: :unsupported_key
                    })

            entry ->
              entry
          end)

        entry ->
          entry
      end)
    end)
  end

  defp validate_text_fields_options(opts) do
    option = :text_fields

    get_validation_entries(opts, option)
    |> Enum.map(fn %{source: source, entries: entries, field_keys: field_keys} ->
      entries
      |> Enum.filter(fn
        field when is_atom(field) ->
          if field in field_keys do
            field
          else
            raise_incorrect_reference(source, [option], field)
          end

        entry ->
          entry
      end)
    end)
  end

  defp validate_facet_fields_options(opts) do
    option = :facet_fields

    get_validation_entries(opts, option)
    |> Enum.map(fn %{source: source, entries: entries, field_keys: field_keys} ->
      entries
      |> Enum.filter(fn
        field when is_atom(field) ->
          if field in field_keys do
            field
          else
            raise_incorrect_reference(source, [option], field)
          end

        {field, _} = entry ->
          if field in field_keys do
            entry
          else
            raise_incorrect_reference(source, [option], field)
          end

        entry ->
          entry
      end)
      # credo:disable-for-next-line
      |> Enum.filter(fn
        {field, [range_bounds: value]} = entry ->
          if is_list(value) and value != [] and Enum.all?(value, &is_number(&1)) do
            entry
          else
            raise InvalidOptionsError.message(%{
                    source: source,
                    path: [option, field],
                    key: :range_bounds,
                    type: :invalid_value,
                    reason: "expected a list of numbers"
                  })
          end

        {field, [label: value]} = entry ->
          if is_atom(value) do
            entry
          else
            raise InvalidOptionsError.message(%{
                    source: source,
                    path: [option, field],
                    key: :label,
                    type: :invalid_value,
                    reason: "expected an atom"
                  })
          end

        {field, [{key, _value}]} ->
          raise InvalidOptionsError.message(%{
                  source: source,
                  path: [option, field],
                  key: key,
                  type: :unsupported_key
                })

        entry ->
          entry
      end)
    end)
  end

  defp validate_sort_fields_options(opts) do
    option = :sort_fields

    get_validation_entries(opts, option)
    |> Enum.map(fn %{source: source, entries: entries, field_keys: field_keys} ->
      entries
      |> Enum.filter(fn
        field when is_atom(field) ->
          if field in field_keys do
            field
          else
            raise_incorrect_reference(source, [option], field)
          end

        {field, _} = entry ->
          if field in field_keys do
            entry
          else
            raise_incorrect_reference(source, [option], field)
          end

        entry ->
          entry
      end)
      # credo:disable-for-next-line
      |> Enum.filter(fn
        {_field, [cast: value]} = entry ->
          if is_atom(value) do
            entry
          else
            raise InvalidOptionsError.message(%{
                    source: source,
                    path: [option],
                    key: :cast,
                    type: :invalid_value,
                    reason: "expected an atom"
                  })
          end

        {_field, [{key, _value}]} ->
          raise InvalidOptionsError.message(%{
                  source: source,
                  path: [option],
                  key: key,
                  type: :unsupported_key
                })

        entry ->
          entry
      end)
    end)
  end

  defp get_validation_entries(opts, key) do
    opts
    |> Keyword.get_values(:sources)
    |> List.flatten()
    |> Enum.reduce([], fn {source, source_options}, acc ->
      entries =
        source_options
        |> Keyword.get_values(key)
        |> List.flatten()

      field_keys = Keyword.get_values(source_options, :fields) |> List.flatten() |> Keyword.keys()

      [
        %{
          source: source,
          entries: entries,
          field_keys: field_keys
        }
        | acc
      ]
    end)
  end

  defp raise_incorrect_reference(source, path, field) do
    raise(
      InvalidOptionsError.message(%{
        source: source,
        path: path,
        key: field,
        type: :incorrect_reference,
        reason: "expected a name that is listed in `fields`"
      })
    )
  end

  defp validate_scope_callback(opts, module) do
    has_scopes_option =
      Keyword.get_values(opts, :sources)
      |> List.flatten()
      |> Enum.map(fn {_, sublist} ->
        Keyword.has_key?(sublist, :scope_keys) and Keyword.get(sublist, :scope_keys) != []
      end)
      |> List.flatten()
      |> Enum.any?()

    require_scope_by_callback(module, has_scopes_option)
  end

  defp require_scope_by_callback(module, has_scopes_option) when has_scopes_option do
    if not Module.defines?(module, {Constants.scope_callback(), 2}) do
      raise MissingCallbackError.message(%{
              callback: "scope_by/2",
              module: module
            })
    end
  end

  defp require_scope_by_callback(_module, _has_scopes_option), do: nil
end
