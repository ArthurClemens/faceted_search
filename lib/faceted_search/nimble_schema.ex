defmodule FacetedSearch.NimbleSchema do
  @moduledoc false

  alias FacetedSearch.Constants
  alias FacetedSearch.Errors.InvalidOptionsError
  alias FacetedSearch.Errors.MissingCallbackError

  @faceted_search_option_schema [
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

  @option_schema NimbleOptions.new!(@faceted_search_option_schema)

  def option_schema, do: @option_schema

  def validate!(opts, module), do: validate!(opts, option_schema(), module)

  def validate!(opts, %NimbleOptions{} = schema, module) do
    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        collected_errors =
          []
          |> validate_options(module, opts, :data_fields,
            validate_keyword_list: true,
            supported_keyword_list_options: [:cast, :binding, :field],
            allow_non_field_keys: true,
            keyword_list_value_types: %{
              cast: :atom,
              binding: :atom,
              field: :atom
            }
          )
          |> validate_options(module, opts, :text_fields, validate_keyword_list: false)
          |> validate_options(module, opts, :facet_fields,
            validate_keyword_list: true,
            supported_keyword_list_options: [:range_bounds, :label],
            keyword_list_value_types: %{
              label: :atom,
              range_bounds: {:array, :number}
            }
          )
          |> validate_options(module, opts, :sort_fields,
            validate_keyword_list: true,
            supported_keyword_list_options: [:cast],
            keyword_list_value_types: %{
              cast: :atom
            }
          )

        if collected_errors != [] do
          raise InvalidOptionsError.message(collected_errors)
        end

        validate_scope_callback(opts, opts[:module])

        # Otherwise: options are valid
        opts

      {:error, err} ->
        raise InvalidOptionsError.from_nimble(err,
                module: module
              )
    end
  end

  defp validate_options(collected_errors, module, opts, option, validation_opts) do
    is_validate_keyword_list = Keyword.get(validation_opts, :validate_keyword_list, false)
    allow_non_field_keys = Keyword.get(validation_opts, :allow_non_field_keys, false)
    supported_keyword_list_options = Keyword.get(validation_opts, :supported_keyword_list_options)
    keyword_list_value_types = Keyword.get(validation_opts, :keyword_list_value_types)

    get_source_entries(opts, option)
    |> Enum.reduce(collected_errors, fn %{entries: entries, data: data}, acc ->
      # First pass: validate field keys
      acc =
        Enum.reduce(entries, acc, fn
          field, acc_1 when is_atom(field) ->
            validate_atom_field_reference(acc_1, module, field, [option], data)

          {field, field_options}, acc_1
          when not allow_non_field_keys and is_atom(field) and is_list(field_options) and
                 field_options != [] ->
            # Ignore custom data entry in data_fields
            validate_atom_field_reference(acc_1, module, field, [option], data)

          {field, field_options}, acc_1 when is_list(field_options) and field_options == [] ->
            add_error_empty_list(acc_1, module, field, [option], data)

          _, acc_1 ->
            acc_1
        end)

      # Second pass: validate key-values that are not keyword lists
      acc =
        Enum.reduce(entries, acc, fn
          {field, [{keyword_list_key, value}]}, acc_1 when is_validate_keyword_list ->
            if Keyword.keyword?(value) do
              # Handle in next pass
              acc_1
            else
              if keyword_list_key in supported_keyword_list_options do
                validate_value_type(
                  acc_1,
                  module,
                  keyword_list_key,
                  [option, field],
                  data,
                  value,
                  keyword_list_value_types[keyword_list_key]
                )
              else
                add_error(
                  acc_1,
                  unsupported_keys_error(
                    module,
                    data.source,
                    [option, field],
                    [keyword_list_key]
                  )
                )
              end
            end

          _, acc_1 ->
            acc_1
        end)

      # Third pass: validate contents of keyword lists
      Enum.reduce(entries, acc, fn
        {field, field_options}, acc_1
        when is_validate_keyword_list and is_atom(field) and is_list(field_options) ->
          validation_fn = fn
            errors, keyword_list_key, [{key, value}] when is_atom(keyword_list_key) ->
              value_types = Map.keys(keyword_list_value_types)

              if key in value_types do
                errors
                |> validate_atom_field_reference(
                  module,
                  keyword_list_key,
                  [option, field],
                  data
                )
                |> validate_value_type(
                  module,
                  keyword_list_key,
                  [option, field],
                  data,
                  value,
                  keyword_list_value_types[key]
                )
              else
                errors
              end

            errors, keyword_list_key, keyword_list
            when is_atom(keyword_list_key) and is_list(keyword_list) and keyword_list == [] ->
              add_error_empty_list(errors, module, keyword_list_key, [option, field], data)

            errors, _, _ ->
              errors
          end

          validate_keyword_list(
            acc_1,
            module,
            field_options,
            [option, field],
            data,
            supported_keyword_list_options,
            keyword_list_value_types,
            validation_fn
          )

        _, acc_1 ->
          acc_1
      end)
    end)
  end

  defp validate_keyword_list(
         errors,
         module,
         keyword_list,
         path,
         data,
         supported_keyword_list_options,
         _keyword_list_value_types,
         validation_fn
       ) do
    Enum.reduce(keyword_list, errors, fn
      keyword_list_key, acc when is_atom(keyword_list_key) ->
        validate_atom_field_reference(acc, module, keyword_list_key, path, data)

      {keyword_list_key, keyword_list}, acc ->
        if Keyword.keyword?(keyword_list) do
          keys = Keyword.keys(keyword_list)
          unsupported_keys = keys -- supported_keyword_list_options

          if unsupported_keys == [] do
            validation_fn.(acc, keyword_list_key, keyword_list)
          else
            add_error(
              acc,
              unsupported_keys_error(
                module,
                data.source,
                path,
                unsupported_keys
              )
            )
          end
        else
          # Ignore: already handled
          acc
        end

      _, acc ->
        acc
    end)
  end

  defp validate_atom_field_reference(errors, module, field, path, data, reason \\ nil) do
    %{source: source, field_keys: field_keys} = data

    if field in field_keys do
      errors
    else
      add_error(errors, incorrect_reference_error(module, source, path, field, reason))
    end
  end

  defp add_error_empty_list(errors, module, field, path, data) do
    %{source: source} = data

    add_error(
      errors,
      invalid_value_error(
        module,
        source,
        path,
        field,
        "Expected a non-empty keyword list."
      )
    )
  end

  defp validate_value_type(errors, module, field, path, data, value, type) do
    if valid_type?(value, type) do
      errors
    else
      add_error(
        errors,
        invalid_value_error(
          module,
          data.source,
          path,
          field,
          "Expected type: #{type |> Kernel.inspect()}."
        )
      )
    end
  end

  defp add_error(errors, error) do
    [error | errors] |> Enum.reverse()
  end

  defp valid_type?(value, type) when type == :atom do
    is_atom(value)
  end

  defp valid_type?(value, type) when type == {:array, :number} do
    is_list(value) and value != [] and Enum.all?(value, &is_number(&1))
  end

  defp valid_type?(_, _), do: false

  defp get_source_entries(opts, option) do
    opts
    |> Keyword.get_values(:sources)
    |> List.flatten()
    |> Enum.reduce([], fn {source, source_options}, acc ->
      entries =
        source_options
        |> Keyword.get_values(option)
        |> List.flatten()

      field_keys = Keyword.get_values(source_options, :fields) |> List.flatten() |> Keyword.keys()

      [
        %{
          entries: entries,
          data: %{source: source, option: option, field_keys: field_keys}
        }
        | acc
      ]
      |> Enum.reverse()
    end)
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

  defp incorrect_reference_error(module, source, path, field, reason) do
    error_entry(
      module,
      source,
      path,
      field,
      :incorrect_reference,
      reason || ~s(Expected a name that is listed in "fields".)
    )
  end

  defp invalid_value_error(module, source, path, field, reason) do
    error_entry(module, source, path, field, :invalid_value, reason)
  end

  defp unsupported_keys_error(module, source, path, options) do
    error_entry(module, source, path, options, :unsupported_option)
  end

  defp error_entry(module, source, path, field_or_options, type, reason \\ nil) do
    %{
      module: module,
      source: source,
      path: path,
      key: field_or_options,
      type: type,
      reason: reason
    }
  end
end
