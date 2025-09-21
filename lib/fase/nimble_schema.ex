defmodule Fase.NimbleSchema do
  @moduledoc false

  alias Fase.Constants
  alias Fase.InvalidOptionsError
  alias Fase.MissingCallbackError
  alias Fase.SchemaValidationData

  @default_schema_fields [
    :id,
    :source,
    :data,
    :text,
    :tsv
  ]
  @fase_option_schema [
    module: [
      type: :atom,
      doc:
        "The schema module that calls `use Fase`. This is inserted automatically."
    ],
    id: [
      type: :keyword_list,
      keys: [
        transforms: [
          type: {:list, :string},
          required: true
        ]
      ]
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
                    column: [type: :atom],
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
              type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}}
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
    ],
    default_order: [
      type: :map,
      keys: [
        order_by: [type: {:list, :atom}],
        order_directions: [
          type:
            {:list,
             {:in,
              [
                :asc,
                :asc_nulls_first,
                :asc_nulls_last,
                :desc,
                :desc_nulls_first,
                :desc_nulls_last
              ]}}
        ]
      ]
    ]
  ]

  @option_schema NimbleOptions.new!(@fase_option_schema)

  def option_schema, do: @option_schema

  def validate!(opts, module), do: validate!(opts, option_schema(), module)

  def validate!(opts, %NimbleOptions{} = schema, module) do
    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        collected_errors =
          []
          |> validate_options(module, opts, :fields,
            get_supported_keyword_list_options: fn
              %{path: [_, _, :fields]}, _keys_map ->
                :ok

              %{path: [_, source, :fields, _], key: :binding, raw: binding_key},
              %{join_keys: join_keys} ->
                if binding_key in join_keys or binding_key == source do
                  :ok
                else
                  %{
                    error: :unlisted_join_binding,
                    key: binding_key,
                    supported_keys: join_keys
                  }
                end

              _, _ ->
                :ok
            end
          )
          |> validate_options(module, opts, :data_fields,
            get_supported_keyword_list_options: fn
              %{
                path: [_, _, :data_fields]
              },
              _keys_map ->
                :ok

              %{
                path: [_, _, :data_fields, _],
                values: %{raw: raw_values} = _values
              },
              _keys_map
              when is_list(raw_values) ->
                if MapSet.subset?(
                     MapSet.new(Keyword.keys(raw_values)),
                     MapSet.new([:binding, :column, :transforms, :ecto_type])
                   ) do
                  :ok
                else
                  key = Keyword.keys(raw_values) |> List.first()

                  %{
                    error: :unlisted,
                    key: key,
                    supported_keys: [
                      :binding,
                      :column,
                      :transforms,
                      :ecto_type
                    ]
                  }
                end

              _, _ ->
                :ok
            end
          )
          |> validate_options(module, opts, :text_fields,
            get_supported_keyword_list_options: fn
              %{path: [_, _, :text_fields, _], key: key, raw: raw}, _
              when key == :transforms ->
                if is_list(raw) and raw != [] do
                  :ok
                else
                  %{
                    error: :empty_lists,
                    key: key,
                    supported_keys: [:transforms]
                  }
                end

              %{path: [_, _, :text_fields, _], key: key}, _ ->
                %{error: :unlisted, key: key, supported_keys: [:transforms]}

              _, _ ->
                :ok
            end
          )
          |> validate_options(module, opts, :facet_fields,
            get_supported_keyword_list_options: fn
              %{path: [_, _, :facet_fields], key: key}, _
              when key == :hierarchies ->
                :ok

              %{path: [_, _, :facet_fields, :hierarchies]}, _ ->
                :ok

              %{path: [_, _, :facet_fields, :hierarchies, key]},
              %{facet_keys: facet_keys} ->
                if key in facet_keys do
                  %{error: :duplicate, key: key, supported_keys: facet_keys}
                else
                  :ok
                end

              %{path: [_, _, :facet_fields], key: key, values: values},
              %{field_keys: field_keys} ->
                if Keyword.keyword?(values.raw) and key in field_keys do
                  :ok
                else
                  %{error: :unlisted, key: key, supported_keys: field_keys}
                end

              %{path: [_, _, :facet_fields, _], key: key}, _keys_map ->
                supported_keys = [
                  :label,
                  :number_range_bounds,
                  :date_range_bounds
                ]

                if key in supported_keys do
                  :ok
                else
                  %{error: :unlisted, key: key, supported_keys: supported_keys}
                end

              _, _ ->
                :ok
            end
          )
          |> validate_options(module, opts, :sort_fields,
            get_supported_keyword_list_options: fn
              %{path: [_, _, :sort_fields, _], key: key}, _keys_map ->
                supported_keys = [
                  :transforms,
                  :ecto_type
                ]

                if key in supported_keys do
                  :ok
                else
                  %{error: :unlisted, key: key, supported_keys: supported_keys}
                end

              _, _ ->
                :ok
            end
          )
          # Place items with same error type together
          |> Enum.group_by(& &1.error_type)
          |> Map.values()
          |> List.flatten()

        if not Enum.empty?(collected_errors) do
          raise InvalidOptionsError.from_validation(collected_errors,
                  module: module
                )
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

  defp validate_options(
         collected_errors,
         module,
         opts,
         option,
         validation_opts
       ) do
    get_source_entries(opts, option)
    |> Enum.reduce(collected_errors, fn %{
                                          processed: processed,
                                          field_keys: field_keys,
                                          facet_keys: facet_keys,
                                          join_keys: join_keys
                                        },
                                        acc ->
      validation_opts =
        validation_opts
        |> Keyword.put_new(:field_keys, field_keys)
        |> Keyword.put_new(:facet_keys, facet_keys)
        |> Keyword.put_new(:join_keys, join_keys)

      Enum.reduce(processed, acc, fn {type, entries}, acc_1 ->
        list_errored_entries(type, entries, validation_opts)
        |> Enum.map(&Map.merge(&1, %{type: type, option: option}))
        |> Enum.concat(acc_1)
      end)
    end)
    |> Enum.map(&to_error_entry(&1, module))
  end

  defp get_source_entries(opts, option) do
    opts
    |> Keyword.get_values(:sources)
    |> List.flatten()
    |> Enum.reduce([], fn {source, source_options}, acc ->
      field_keys =
        Keyword.get_values(source_options, :fields)
        |> List.flatten()
        |> Keyword.keys()

      join_keys =
        Keyword.get_values(source_options, :joins)
        |> List.flatten()
        |> Enum.map(fn
          key when is_atom(key) -> key
          {key, _} -> key
        end)

      facet_keys =
        Keyword.get_values(source_options, :facet_fields)
        |> List.flatten()
        |> Enum.map(fn
          key when is_atom(key) -> key
          {key, _} -> key
        end)

      entries =
        source_options
        |> Keyword.get_values(option)
        |> List.flatten()

      processed_entries = process_entries(entries, [:sources, source, option])

      [
        %{
          entries: entries,
          processed: processed_entries,
          source: source,
          join_keys: join_keys,
          field_keys: field_keys,
          facet_keys: facet_keys
        }
        | acc
      ]
      |> Enum.reverse()
    end)
  end

  defp process_entries(entries, path) do
    merge_entries = fn entries, acc ->
      Enum.reduce(entries, acc, fn
        {key, value}, acc ->
          Map.update(acc, key, [], fn existing ->
            [value | existing] |> List.flatten()
          end)

        _, acc ->
          acc
      end)
    end

    Enum.reduce(
      entries,
      %{
        atom_keys: [],
        empty_keyword_lists: [],
        keyword_lists: [],
        key_values: []
      },
      fn
        # empty_keyword_lists
        {key, values}, acc when values == [] ->
          Map.update(acc, :empty_keyword_lists, [], fn existing ->
            [%{key: key, path: path} | existing]
          end)

        # keyword_lists and non_keyword_lists (typed to key_values)
        {key, values}, acc when is_list(values) ->
          is_keyword_list = Keyword.keyword?(values)
          type = if is_keyword_list, do: :keyword_lists, else: :key_values

          # Recurse
          acc = process_entries(values, path ++ [key]) |> merge_entries.(acc)

          Map.update(acc, type, [], fn existing ->
            new_entry =
              if is_keyword_list do
                %{key: key, path: path, values: %{raw: values}}
              else
                %{key: key, path: path, raw: values}
              end

            [new_entry | existing]
          end)

        # atom_keys
        key, acc when is_atom(key) ->
          Map.update(acc, :atom_keys, [], fn existing ->
            [%{key: key, path: path} | existing]
          end)

        # key_values
        {key, value}, acc ->
          Map.update(acc, :key_values, [], fn existing ->
            [%{key: key, path: path, raw: value} | existing]
          end)

        _, acc ->
          acc
      end
    )
    |> Enum.filter(fn
      {_k, v} when v == [] -> false
      _ -> true
    end)
  end

  defp list_errored_entries(:empty_keyword_lists, entries, _validation_opts) do
    entries |> insert_error_type(:empty_keyword_lists)
  end

  defp list_errored_entries(:atom_keys, entries, validation_opts) do
    field_keys =
      @default_schema_fields
      |> Enum.concat(Keyword.get(validation_opts, :field_keys, []))
      |> Enum.uniq()

    entries
    |> Enum.filter(&(&1.key not in field_keys))
    |> insert_error_type(:invalid_key)
  end

  defp list_errored_entries(:keyword_lists, entries, validation_opts) do
    entries
    |> Enum.reduce([], fn entry, acc ->
      %{
        key: key,
        error_type: error_type,
        has_supported_keys: has_supported_keys,
        supported_keyword_list_option_keys: supported_keyword_list_option_keys
      } =
        get_supported_key_data(entry, validation_opts)

      if is_nil(error_type) or has_supported_keys do
        acc
      else
        [
          SchemaValidationData.new(
            Map.merge(entry, %{
              error_type: error_type,
              key: key,
              supported_keys: supported_keyword_list_option_keys
            })
          )
          | acc
        ]
      end
    end)
  end

  defp list_errored_entries(:key_values, entries, validation_opts) do
    unsupported_options =
      entries
      |> Enum.reduce([], fn entry, acc ->
        %{
          key: key,
          error_type: error_type,
          has_supported_keys: has_supported_keys,
          supported_keyword_list_option_keys: supported_keyword_list_option_keys
        } =
          get_supported_key_data(entry, validation_opts)

        if is_nil(error_type) or has_supported_keys do
          acc
        else
          [
            SchemaValidationData.new(
              Map.merge(entry, %{
                key: key,
                error_type: error_type,
                supported_keys: supported_keyword_list_option_keys
              })
            )
            | acc
          ]
        end
      end)

    invalid_values =
      entries
      |> Enum.reduce([], fn %{raw: raw} = entry, acc ->
        %{
          key: key,
          error_type: error_type,
          supported_keyword_list_options: supported_keyword_list_options
        } =
          get_supported_key_data(entry, validation_opts)

        type = supported_keyword_list_options[key]

        if is_nil(error_type) or valid_type?(raw, type) do
          acc
        else
          [
            SchemaValidationData.new(
              Map.merge(entry, %{
                key: key,
                error_type: error_type,
                expected_type: error_message_type(type)
              })
            )
            | acc
          ]
        end
      end)

    Enum.concat(unsupported_options, invalid_values)
    |> Enum.uniq_by(&[&1.key | &1.path])
  end

  defp get_supported_key_data(entry, validation_opts) do
    field_keys =
      @default_schema_fields
      |> Enum.concat(Keyword.get(validation_opts, :field_keys, []))
      |> Enum.uniq()

    get_supported_keyword_list_options =
      Keyword.get(validation_opts, :get_supported_keyword_list_options)

    case get_supported_keyword_list_options.(entry, %{
           field_keys: field_keys,
           facet_keys: Keyword.get(validation_opts, :facet_keys, []),
           join_keys: Keyword.get(validation_opts, :join_keys, [])
         }) do
      :ok ->
        %{
          key: entry.key,
          error_type: nil,
          has_supported_keys: true,
          supported_keyword_list_options: [],
          supported_keyword_list_option_keys: []
        }

      %{error: error_type, key: key, supported_keys: supported_keys} ->
        %{
          key: key,
          error_type: error_type,
          has_supported_keys: false,
          supported_keyword_list_options: [],
          supported_keyword_list_option_keys: supported_keys
        }
    end
  end

  defp insert_error_type(list, error_type) do
    Enum.map(list, &Map.put(&1, :error_type, error_type))
  end

  defp valid_type?(value, type) when type == :atom, do: is_atom(value)
  defp valid_type?(value, type) when type == :boolean, do: is_boolean(value)

  defp valid_type?(value, type) when type == {:array, :number} do
    is_list(value) and value != [] and Enum.all?(value, &is_number(&1))
  end

  defp valid_type?(value, type) when type == {:array, :string} do
    is_list(value) and value != [] and Enum.all?(value, &is_binary(&1))
  end

  defp valid_type?(value, type) when type == {:array, :atom} do
    is_list(value) and value != [] and Enum.all?(value, &is_atom(&1))
  end

  defp valid_type?(_, _), do: false

  defp error_message_type(:atom), do: "atom"
  defp error_message_type({:array, :number}), do: "list of numbers"
  defp error_message_type({:array, :atom}), do: "list of atoms"
  defp error_message_type(type), do: type

  defp to_error_entry(entry, module) do
    entry
    |> Map.drop([:raw, :values])
    |> Map.put(:module, module)
  end

  defp validate_scope_callback(opts, module) do
    has_scopes_option =
      Keyword.get_values(opts, :sources)
      |> List.flatten()
      |> Enum.map(fn {_, sublist} ->
        Keyword.has_key?(sublist, :scope_keys) and
          Keyword.get(sublist, :scope_keys) != []
      end)
      |> List.flatten()
      |> Enum.any?()

    require_scope_by_callback(module, has_scopes_option)
  end

  defp require_scope_by_callback(module, has_scopes_option)
       when has_scopes_option do
    if not Module.defines?(module, {Constants.scope_callback(), 2}) do
      raise MissingCallbackError.message(%{
              callback: "scope_by/2",
              module: module
            })
    end
  end

  defp require_scope_by_callback(_module, _has_scopes_option), do: nil
end
