defmodule FacetedSearch.NimbleSchema do
  @moduledoc false

  alias FacetedSearch.Constants
  alias FacetedSearch.Errors.InvalidOptionsError
  alias FacetedSearch.Errors.MissingCallbackError

  @default_schema_fields [
    :id,
    :source,
    :data,
    :text,
    :tsv
  ]
  @faceted_search_option_schema [
    module: [
      type: :atom,
      doc:
        "The schema module that calls `use FacetedSearch`. This is inserted automatically."
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
            get_supported_keyword_list_options: fn
              %{path: [_, _, :data_fields]}, _field_keys ->
                :any

              %{path: [_, _, :data_fields, _], key: key, values: values},
              field_keys ->
                if Keyword.keyword?(values.raw) and key in field_keys do
                  :any
                else
                  if MapSet.equal?(
                       MapSet.new([:binding, :field]),
                       MapSet.new(Keyword.keys(values.raw))
                     ) do
                    :any
                  else
                    field_keys
                  end
                end

              %{path: [_, _, :data_fields, _, _]}, _field_keys ->
                %{
                  binding: :atom,
                  field: :atom,
                  cast: :atom
                }

              _, _ ->
                nil
            end
          )
          |> validate_options(module, opts, :text_fields)
          |> validate_options(module, opts, :facet_fields,
            get_supported_keyword_list_options: fn
              %{path: [_, _, :facet_fields], key: key}, _
              when key == :hierarchies ->
                :any

              %{path: [_, _, :facet_fields, :hierarchies]}, _ ->
                :any

              %{path: [_, _, :facet_fields, :hierarchies, _]}, _field_keys ->
                %{
                  path: {:array, :atom},
                  label: :atom,
                  parent: :atom,
                  hide_when_selected: :boolean
                }

              %{path: [_, _, :facet_fields], key: key, values: values},
              field_keys ->
                if Keyword.keyword?(values.raw) and key in field_keys do
                  :any
                else
                  field_keys
                end

              %{path: [_, _, :facet_fields, _]}, _field_keys ->
                %{
                  label: :atom,
                  number_range_bounds: {:array, :number},
                  date_range_bounds: {:array, :string}
                }

              _, _ ->
                nil
            end
          )
          |> validate_options(module, opts, :sort_fields,
            get_supported_keyword_list_options: fn
              _, _ -> %{cast: :atom}
            end
          )
          # Place items with same error type together
          |> Enum.group_by(& &1.error_type)
          |> Map.values()
          |> List.flatten()

        if not Enum.empty?(collected_errors) do
          raise InvalidOptionsError.messages(collected_errors)
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
         validation_opts \\ []
       ) do
    get_source_entries(opts, option)
    |> Enum.reduce(collected_errors, fn %{
                                          processed: processed,
                                          field_keys: field_keys
                                        },
                                        acc ->
      validation_opts =
        Keyword.put_new(validation_opts, :field_keys, field_keys)

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
          field_keys: field_keys
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
      %{atom_keys: [], empty_lists: [], keyword_lists: [], key_values: []},
      fn
        # empty_lists
        {key, values}, acc when values == [] ->
          Map.update(acc, :empty_lists, [], fn existing ->
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

  defp list_errored_entries(:empty_lists, entries, _validation_opts) do
    entries |> insert_error_type(:empty_lists)
  end

  defp list_errored_entries(:atom_keys, entries, validation_opts) do
    field_keys =
      @default_schema_fields
      |> Enum.concat(Keyword.get(validation_opts, :field_keys, []))
      |> Enum.uniq()

    entries
    |> Enum.filter(&(&1.key not in field_keys))
    |> insert_error_type(:invalid_reference)
  end

  defp list_errored_entries(:keyword_lists, entries, validation_opts) do
    entries
    |> Enum.reduce([], fn entry, acc ->
      value_keys =
        get_in(entry, [:values, :raw])
        |> case do
          nil -> []
          value -> Keyword.keys(value)
        end

      %{
        has_supported_keys: has_supported_keys,
        supported_keyword_list_option_keys: supported_keyword_list_option_keys
      } =
        supported_keys?(entry, validation_opts, value_keys)

      if has_supported_keys do
        acc
      else
        [
          Map.put(entry, :supported_keys, supported_keyword_list_option_keys)
          | acc
        ]
      end
    end)
    |> insert_error_type(:unsupported_option)
  end

  defp list_errored_entries(:key_values, entries, validation_opts) do
    unsupported_options =
      entries
      |> Enum.reduce([], fn entry, acc ->
        %{
          has_supported_keys: has_supported_keys,
          supported_keyword_list_option_keys: supported_keyword_list_option_keys
        } =
          supported_keys?(entry, validation_opts)

        if has_supported_keys do
          acc
        else
          [
            Map.put(entry, :supported_keys, supported_keyword_list_option_keys)
            | acc
          ]
        end
      end)
      |> insert_error_type(:unsupported_option)

    invalid_values =
      entries
      |> Enum.reduce([], fn %{key: key, raw: raw} = entry, acc ->
        %{supported_keyword_list_options: supported_keyword_list_options} =
          supported_keys?(entry, validation_opts)

        type = supported_keyword_list_options[key]

        if valid_type?(raw, type) do
          acc
        else
          [Map.put(entry, :expected_type, error_message_type(type)) | acc]
        end
      end)
      |> insert_error_type(:invalid_value)

    Enum.concat(unsupported_options, invalid_values)
    |> Enum.uniq_by(&[&1.key | &1.path])
  end

  defp supported_keys?(entry, validation_opts, value_keys \\ nil) do
    field_keys =
      @default_schema_fields
      |> Enum.concat(Keyword.get(validation_opts, :field_keys, []))
      |> Enum.uniq()

    get_supported_keyword_list_options =
      Keyword.get(validation_opts, :get_supported_keyword_list_options)

    case get_supported_keyword_list_options.(entry, field_keys) do
      :any ->
        %{
          has_supported_keys: true,
          supported_keyword_list_options: [],
          supported_keyword_list_option_keys: []
        }

      options when is_map(options) and is_list(value_keys) ->
        option_keys = Map.keys(options)

        has_supported_keys =
          MapSet.subset?(
            MapSet.new(value_keys),
            MapSet.new(option_keys)
          )

        %{
          has_supported_keys: has_supported_keys,
          supported_keyword_list_options: options,
          supported_keyword_list_option_keys: option_keys
        }

      options when is_map(options) ->
        option_keys = Map.keys(options)

        supported_keys =
          option_keys
          |> Enum.concat(field_keys)
          |> Enum.uniq()

        %{
          has_supported_keys: entry.key in supported_keys,
          supported_keyword_list_options: options,
          supported_keyword_list_option_keys: option_keys
        }

      _ ->
        %{
          has_supported_keys: false,
          supported_keyword_list_options: [],
          supported_keyword_list_option_keys: field_keys
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
