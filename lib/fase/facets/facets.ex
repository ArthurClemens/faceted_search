defmodule Fase.Facets do
  @moduledoc false

  use Fase.Internal.Types,
    include: [:facet_search_options, :search]

  import Ecto.Query, warn: false

  require Logger

  alias Fase.Cache
  alias Fase.Facet
  alias Fase.Facets.FacetSearch
  alias Fase.Internal.Constants
  alias Fase.Internal.FacetConfig
  alias Fase.Option

  @typep facet_result_state :: %{
           count: integer(),
           database_label: String.t() | nil,
           field: atom(),
           hierarchy: boolean(),
           name: String.t(),
           parent: atom() | nil,
           range_bucket_value: {list(), integer()} | nil,
           selected: boolean(),
           value: term()
         }
  @typep facet_result_states :: %{
           atom() => facet_result_state()
         }

  # ------------------------------------------------
  # Search functions
  # ------------------------------------------------

  @spec search(Ecto.Queryable.t(), map() | nil, [facet_search_option()]) ::
          {:ok, list(Facet.t())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
          | {:error, :no_cache}
          | {:error, :no_repo}

  def search(
        ecto_schema,
        raw_search_params \\ %{},
        facet_search_options \\ []
      ) do
    {view_name, module} = ecto_schema

    search_params =
      FacetSearch.normalize_search_params(raw_search_params, module)

    search_view_description = Fase.search_view_description(module)
    facet_configs = FacetConfig.facet_configs(search_view_description)

    {cache_key, is_read_from_cache} =
      cache_read_state(search_params, facet_search_options)

    if is_read_from_cache do
      case Cache.get(Cache, view_name, cache_key) do
        {:ok, facets} ->
          {:ok, facets}

        {:error, :no_cache} ->
          case search_and_process_facets(
                 module,
                 ecto_schema,
                 search_params,
                 facet_configs,
                 facet_search_options
               ) do
            {:ok, facets} ->
              Cache.insert(Cache, view_name, cache_key, facets)
              {:ok, facets}

            error ->
              error
          end
      end
    else
      search_and_process_facets(
        module,
        ecto_schema,
        search_params,
        facet_configs,
        facet_search_options
      )
    end
  end

  @spec search_and_process_facets(
          module(),
          Ecto.Queryable.t(),
          map(),
          facet_configs(),
          [
            facet_search_option()
          ]
        ) ::
          {:ok, list(Facet.t())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
          | {:error, :no_repo}
  defp search_and_process_facets(
         module,
         ecto_schema,
         search_params,
         facet_configs,
         facet_search_options
       ) do
    case FacetSearch.search_facets(
           ecto_schema,
           search_params,
           facet_configs,
           facet_search_options
         ) do
      {:ok, rows} ->
        facets =
          process_search_results(
            module,
            rows,
            search_params,
            facet_configs,
            facet_search_options
          )

        {:ok, facets}

      error ->
        error
    end
  end

  @spec process_search_results(
          module(),
          list(result_row()),
          map(),
          facet_configs(),
          [facet_search_option()]
        ) ::
          list(Facet.t())
  defp process_search_results(
         module,
         rows,
         search_params,
         facet_configs,
         facet_search_options
       ) do
    prefix = Constants.facet_search_field_prefix()

    search_params_value_lookup =
      search_params.filters
      |> Enum.reduce(%{}, fn %{field: field, value: values}, acc ->
        Map.put(
          acc,
          field |> to_string() |> String.trim_leading(prefix),
          values
        )
      end)

    result_states =
      create_facet_result_states(
        rows,
        facet_configs,
        search_params_value_lookup
      )
      |> process_hierarchies(search_params_value_lookup, facet_configs)

    create_facets(
      module,
      result_states,
      facet_configs,
      facet_search_options
    )
  end

  defp process_hierarchies(
         facet_result_states,
         search_params_value_lookup,
         facet_configs
       ) do
    derived_parent_values =
      derive_parent_values(search_params_value_lookup, facet_configs)

    facet_result_states
    |> auto_select_parent_values(derived_parent_values)
    |> only_keep_children_of_selected_parents(derived_parent_values)
  end

  defp derive_parent_values(search_params_value_lookup, facet_configs) do
    name_to_field_lookup =
      Enum.reduce(facet_configs, %{}, fn {_, facet_config}, acc ->
        Map.put(acc, facet_config.name, facet_config.field)
      end)

    hierarchy_facet_configs =
      Enum.filter(facet_configs, fn {_name, config} -> !!config.hierarchy end)

    parent_lookup =
      hierarchy_facet_configs
      |> Enum.reduce(%{}, fn {name, config}, acc ->
        Map.put(acc, name, config.parent)
      end)

    hierarchy_facet_config_name_lookup =
      Enum.reduce(hierarchy_facet_configs, %{}, fn {_name, config}, acc ->
        Map.put(acc, config.name, true)
      end)

    hierarchy_search_params_value_lookup =
      Enum.reduce(search_params_value_lookup, %{}, fn {name, value}, acc ->
        if hierarchy_facet_config_name_lookup[name] do
          Map.put(acc, name, value)
        else
          acc
        end
      end)

    facet_value_list =
      Enum.reduce(hierarchy_search_params_value_lookup, [], fn {name, values},
                                                               acc ->
        Enum.concat(
          Enum.reduce(values, [], fn value, acc_1 ->
            Enum.concat(
              Map.new([{name_to_field_lookup[name], value}]),
              acc_1
            )
          end),
          acc
        )
      end)

    separator = Constants.hierarchy_separator()

    Enum.reduce(facet_value_list, facet_value_list, fn {facet_name, value},
                                                       acc ->
      Enum.concat(
        collect_parent_values(
          facet_name,
          value |> String.split(separator),
          parent_lookup,
          []
        ),
        acc
      )
    end)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn {facet_name, parent_value}, acc ->
      Map.update(acc, facet_name, [parent_value], fn existing ->
        [parent_value | existing]
      end)
    end)
  end

  defp collect_parent_values(
         _facet_name,
         value_parts,
         _parent_lookup,
         collected
       )
       when value_parts == [],
       do: collected

  defp collect_parent_values(facet_name, value_parts, parent_lookup, collected) do
    parent_facet_name = parent_lookup[facet_name]

    if parent_facet_name == nil do
      collected
    else
      parent_value_parts =
        value_parts
        |> Enum.reverse()
        |> tl()
        |> Enum.reverse()

      parent_value =
        Enum.join(parent_value_parts, Constants.hierarchy_separator())

      collected =
        Enum.concat(
          Map.new([{parent_facet_name, parent_value}]),
          collected
        )

      collect_parent_values(
        parent_facet_name,
        parent_value_parts,
        parent_lookup,
        collected
      )
    end
  end

  # Auto-select parent values based on value path
  defp auto_select_parent_values(facet_result_states, derived_parent_values) do
    facet_result_states
    |> Enum.reduce([], fn {facet_name, states} = kv, acc ->
      parent_values_to_select = derived_parent_values[facet_name]

      if parent_values_to_select do
        updated_states =
          Enum.map(
            states,
            &Map.put(&1, :selected, &1.value in parent_values_to_select)
          )

        [{facet_name, updated_states} | acc]
      else
        [kv | acc]
      end
    end)
  end

  defp only_keep_children_of_selected_parents(
         facet_result_states,
         derived_parent_values
       ) do
    facet_result_states
    |> Enum.reduce([], fn {facet_name, states}, acc ->
      valid_states =
        Enum.filter(
          states,
          &filter_children_of_selected_parent(&1, derived_parent_values)
        )

      [{facet_name, valid_states} | acc]
    end)
  end

  # Filter options where the "parent" part of the value matches one of the selected parents
  defp filter_children_of_selected_parent(
         %{hierarchy: hierarchy, parent: parent} = state,
         derived_parent_values
       )
       when hierarchy == true and not is_nil(parent) do
    parent_values = derived_parent_values[parent]

    if parent_values do
      separator = Constants.hierarchy_separator()

      parent_value_to_match =
        state.value
        |> String.split(separator)
        |> Enum.reverse()
        |> tl()
        |> Enum.reverse()
        |> Enum.join(separator)

      parent_value_to_match in parent_values
    else
      false
    end
  end

  defp filter_children_of_selected_parent(state, _), do: state

  @spec create_facets(
          module(),
          facet_result_states(),
          facet_configs(),
          [facet_search_option()]
        ) :: list(Facet.t())
  defp create_facets(
         module,
         facet_result_states,
         facet_configs,
         facet_search_options
       ) do
    has_facet_label_callback =
      Kernel.function_exported?(module, Constants.facet_label_callback(), 2)

    scope = Keyword.get(facet_search_options, :scope)

    create_facet_label = fn field ->
      label =
        if has_facet_label_callback do
          apply(module, Constants.facet_label_callback(), [
            field,
            scope
          ])
        end

      label || humanize(field)
    end

    facet_result_states
    |> Enum.reduce([], fn
      {_field, states}, acc when states == [] ->
        acc

      {field, states}, acc ->
        facet_config = get_in(facet_configs, [Access.key(field)])

        options =
          Enum.map(
            states,
            &create_option(module, &1, scope)
          )

        if facet_config.hide_when_selected and Enum.any?(options, & &1.selected) do
          acc
        else
          [
            %Facet{
              field: field,
              label: create_facet_label.(field),
              parent: facet_config.parent,
              options: options
            }
            | acc
          ]
        end
    end)
    |> Enum.reverse()
  end

  @spec create_option(
          module(),
          facet_result_state(),
          term()
        ) ::
          Option.t()
  defp create_option(module, facet_result_state, scope) do
    %{
      count: count,
      database_label: database_label,
      field: field,
      range_bucket_value: range_bucket_value,
      selected: selected,
      value: value
    } = facet_result_state

    has_option_label_callback =
      Kernel.function_exported?(module, Constants.option_label_callback(), 4)

    option_label =
      if has_option_label_callback do
        apply(module, Constants.option_label_callback(), [
          field,
          range_bucket_value || value,
          database_label,
          scope
        ])
      end

    %Option{
      value: value,
      label: option_label || database_label || to_string(value),
      count: count,
      selected: selected
    }
  end

  @spec create_facet_result_states(list(result_row()), facet_configs(), map()) ::
          facet_result_states()
  defp create_facet_result_states(
         facet_rows,
         facet_configs,
         search_params_value_lookup
       ) do
    facet_config_list =
      Enum.map(facet_configs, fn {_, facet_config} -> facet_config end)

    facet_rows
    |> Enum.map(fn {name, _, _, _} = row ->
      facet_config =
        Enum.find(facet_config_list, &(&1.name == name))

      %{
        facet_config: facet_config,
        row: row
      }
    end)
    |> Enum.filter(&(not is_nil(&1.facet_config)))
    |> Enum.map(fn %{facet_config: facet_config, row: row} ->
      {name, raw_value, database_label, count} = row

      value = FacetSearch.cast_value(raw_value, facet_config)

      selected =
        !!search_params_value_lookup[name] and
          value in search_params_value_lookup[name]

      %{
        count: count,
        database_label: database_label,
        field: facet_config.field,
        hierarchy: !!facet_config.hierarchy,
        name: name,
        parent: facet_config.parent,
        range_bucket_value: maybe_get_range_bucket_value(value, facet_config),
        selected: selected,
        value: value
      }
    end)
    |> Enum.group_by(& &1.field)
  end

  # If range_buckets contains valid entries, return the bucket for the given value
  # otherwise, return the value unchanged.
  defp maybe_get_range_bucket_value(
         value,
         %{range_buckets: range_buckets} = _facet_config
       )
       when is_list(range_buckets) and range_buckets != [] do
    Enum.find(range_buckets, fn {_bounds, bucket} -> bucket == value end)
  end

  defp maybe_get_range_bucket_value(_, _), do: nil

  # Copied from Phoenix.Naming
  # Converts a field name into its humanize version.
  @spec humanize(atom | String.t()) :: String.t()
  def humanize(atom) when is_atom(atom),
    do: humanize(Atom.to_string(atom))

  def humanize(bin) when is_binary(bin) do
    bin =
      if String.ends_with?(bin, "_id") do
        binary_part(bin, 0, byte_size(bin) - 3)
      else
        bin
      end

    bin |> String.replace("_", " ") |> String.capitalize()
  end

  # ------------------------------------------------
  # Cache functions
  # ------------------------------------------------

  defp cache_read_state(search_params, facet_search_options) do
    cache_key = search_params.filters
    has_cache_key = cache_key != []

    is_cache_facets =
      Keyword.get(facet_search_options, :cache_facets, false)

    cache_pid = Process.whereis(Cache)

    {cache_key, is_cache_facets and has_cache_key and is_pid(cache_pid)}
  end

  # clear_cache

  @spec clear_cache(Ecto.Queryable.t()) :: no_return()
  def clear_cache(ecto_schema) do
    {view_name, _module} = ecto_schema
    Cache.clear(Cache, view_name)
  end

  # cached

  @spec cached?(Ecto.Queryable.t(), map()) :: boolean()
  def cached?(ecto_schema, raw_search_params) do
    {view_name, module} = ecto_schema

    search_params =
      FacetSearch.normalize_search_params(raw_search_params, module)

    cache_key = search_params.filters

    Cache.cache_key?(Cache, view_name, cache_key)
  end

  # warm_cache

  @spec warm_cache(Ecto.Queryable.t(), list(map()), [facet_search_option()]) ::
          no_return()
  def warm_cache(ecto_schema, search_params_list, facet_search_options \\ []) do
    {view_name, module} = ecto_schema

    search_view_description = Fase.search_view_description(module)
    facet_configs = FacetConfig.facet_configs(search_view_description)

    search_params_list
    |> Enum.each(fn raw_search_params ->
      search_params =
        FacetSearch.normalize_search_params(raw_search_params, module)

      {cache_key, _} =
        cache_read_state(search_params, facet_search_options)

      case search_and_process_facets(
             module,
             ecto_schema,
             search_params,
             facet_configs,
             facet_search_options
           ) do
        {:ok, facets} ->
          Cache.insert(Cache, view_name, cache_key, facets)
          {:ok, facets}

        _error ->
          nil
      end
    end)
  end
end
