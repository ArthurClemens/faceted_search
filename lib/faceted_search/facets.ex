defmodule FacetedSearch.Facets do
  @moduledoc false

  use FacetedSearch.Types,
    include: [:facet_search_options]

  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Adapters.SQL
  alias FacetedSearch.Cache
  alias FacetedSearch.Config
  alias FacetedSearch.Constants
  alias FacetedSearch.Facet
  alias FacetedSearch.FacetConfig
  alias FacetedSearch.Option

  @typep result_value :: String.t()
  @typep result_label :: String.t()
  @typep result_count :: integer()
  @typep result_row :: {result_value(), result_label(), result_count()}
  @typep facet_configs :: %{
           atom() => FacetConfig.t()
         }
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

  @spec search(Ecto.Queryable.t(), map() | nil, [facet_search_option()]) ::
          {:ok, list(Facet.t())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}

  def search(
        ecto_schema,
        raw_search_params \\ %{},
        facet_search_options \\ []
      ) do
    search_params = clean_search_params(raw_search_params)

    is_cache_facets = Keyword.get(facet_search_options, :cache_facets)

    get_facet_results(
      ecto_schema,
      search_params,
      facet_search_options,
      is_cache_facets,
      Process.whereis(Cache)
    )
  end

  defp get_facet_results(
         _ecto_schema,
         _search_params,
         _facet_search_options,
         is_cache_facets,
         cache_pid
       )
       when is_cache_facets and not is_pid(cache_pid) do
    Logger.error(
      "FacetedSearch.Cache process is not running. Make sure to add it to a supervisor."
    )

    {:error, :no_cache_process}
  end

  defp get_facet_results(
         ecto_schema,
         search_params,
         facet_search_options,
         is_cache_facets,
         _cache_pid
       )
       when is_cache_facets do
    {view_name, _module} = ecto_schema
    cache_key = search_params.filters

    case Cache.get(Cache, view_name, cache_key) do
      {:ok, facet_results} ->
        {:ok, facet_results}

      {:error, :no_cache} ->
        create_and_cache_facet_results(
          ecto_schema,
          search_params,
          facet_search_options
        )
    end
  end

  defp get_facet_results(
         ecto_schema,
         search_params,
         facet_search_options,
         _is_cache_facets,
         _cache_pid
       ) do
    create_facet_results(ecto_schema, search_params, facet_search_options)
  end

  @spec create_and_cache_facet_results(Ecto.Queryable.t(), map(), [
          facet_search_option()
        ]) ::
          {:ok, list(result_row())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
  defp create_and_cache_facet_results(
         ecto_schema,
         search_params,
         facet_search_options
       ) do
    {view_name, _module} = ecto_schema
    cache_key = search_params.filters

    case create_facet_results(ecto_schema, search_params, facet_search_options) do
      {:ok, facet_results} ->
        Cache.insert(Cache, view_name, cache_key, facet_results)
        {:ok, facet_results}

      error ->
        error
    end
  end

  @spec clear_cache(Ecto.Queryable.t()) :: no_return()
  def clear_cache(ecto_schema) do
    {view_name, _module} = ecto_schema
    Cache.clear(Cache, view_name)
  end

  @spec warm_cache(Ecto.Queryable.t(), list(map()), [facet_search_option()]) ::
          no_return()
  def warm_cache(ecto_schema, search_params_list, facet_search_options \\ []) do
    {view_name, _module} = ecto_schema

    search_params_list
    |> Enum.each(fn raw_search_params ->
      search_params = clean_search_params(raw_search_params)
      cache_key = search_params.filters

      data =
        create_facet_results(ecto_schema, search_params, facet_search_options)

      Cache.insert(Cache, view_name, cache_key, data)
    end)
  end

  @spec create_facet_results(Ecto.Queryable.t(), map(), [facet_search_option()]) ::
          {:ok, list(result_row())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
  defp create_facet_results(ecto_schema, search_params, facet_search_options) do
    repo =
      Keyword.get(
        facet_search_options,
        :repo,
        Config.get_repo(facet_search_options)
      )

    {_view_name, module} = ecto_schema
    search_view_description = FacetedSearch.search_view_description(module)
    facet_configs = FacetConfig.facet_configs(search_view_description)

    opts = Keyword.put(facet_search_options, :for, module)

    search_params_without_facets =
      create_search_params_without_facets(search_params, facet_configs)

    with {:ok, all_facet_rows} <-
           get_facet_results(
             repo,
             ecto_schema,
             search_params_without_facets,
             opts
           ),
         {:ok, filtered_facet_rows} <-
           maybe_get_facet_results(repo, ecto_schema, search_params, opts) do
      facet_results =
        consolidate_facet_results(
          module,
          all_facet_rows,
          filtered_facet_rows,
          search_params,
          facet_configs
        )

      {:ok, facet_results}
    else
      error -> error
    end
  end

  @spec create_search_params_without_facets(map(), facet_configs()) :: map()
  defp create_search_params_without_facets(
         %{filters: filters} = search_params,
         facet_configs
       )
       when is_list(filters) do
    prefix = Constants.facet_search_field_prefix()

    facet_fields =
      Map.keys(facet_configs) |> Enum.map(&"#{prefix}#{&1}")

    update_in(search_params, [:filters], fn filters ->
      Enum.filter(filters, &(to_string(&1.field) not in facet_fields))
    end)
  end

  defp create_search_params_without_facets(search_params, _facet_configs),
    do: search_params

  @spec maybe_get_facet_results(
          Ecto.Repo.t(),
          Ecto.Queryable.t(),
          map(),
          Keyword.t()
        ) ::
          {:ok, list(result_row())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
  defp maybe_get_facet_results(
         repo,
         ecto_schema,
         %{filters: filters} = search_params,
         opts
       ) do
    facet_filters =
      Enum.filter(filters, fn %{field: field} ->
        String.starts_with?(
          field |> to_string(),
          Constants.facet_search_field_prefix()
        )
      end)

    if facet_filters == [] do
      {:ok, []}
    else
      get_facet_results(repo, ecto_schema, search_params, opts)
    end
  end

  @spec get_facet_results(Ecto.Repo.t(), Ecto.Queryable.t(), map(), Keyword.t()) ::
          {:ok, list(result_row())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
  defp get_facet_results(repo, ecto_schema, search_params, opts) do
    case Flop.validate(search_params, opts) do
      {:ok, flop} ->
        ecto_schema
        |> create_facets_query(repo, flop, opts)
        |> run_query(repo)

      {:error, meta} ->
        {:error, meta}
    end
  end

  @spec create_facets_query(
          Ecto.Queryable.t(),
          Ecto.Repo.t(),
          Flop.t(),
          Keyword.t()
        ) ::
          String.t()
  defp create_facets_query(ecto_schema, repo, flop, opts) do
    query_opts = Keyword.get(opts, :query_opts, [])
    prefix = Keyword.get(query_opts, :prefix, nil)

    query =
      from(ecto_schema, as: :document, prefix: ^prefix)
      |> Flop.filter(flop, opts)
      |> select([document: document], document.id)
      |> exclude(:limit)
      |> exclude(:order_by)

    {sql, params} = repo.to_sql(:all, query)

    sql_with_tsv = String.replace(sql, ~s("id"), ~s("tsv"))

    sql_with_variables =
      params
      |> Enum.with_index()
      |> Enum.reduce(sql_with_tsv, fn
        {param, index}, acc when is_list(param) ->
          acc
          |> String.replace(
            "$#{index + 1}",
            "ARRAY[#{param |> Enum.map_join(",", &~s('#{&1}'))}]"
          )

        {param, index}, acc when is_binary(param) ->
          acc |> String.replace("$#{index + 1}", ~s('#{param}'))

        {param, index}, acc ->
          acc |> String.replace("$#{index + 1}", ~s(#{param}))
      end)

    separator = Constants.tsv_separator()

    """
    SELECT
      split_part(word, '#{separator}', 1) AS attr,
      split_part(word, '#{separator}', 2) AS value,
      split_part(word, '#{separator}', 3) AS label,
      ndoc AS count
    FROM ts_stat($$
      #{sql_with_variables}
    $$)
    ORDER BY word;
    """
  end

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec run_query(String.t(), Ecto.Repo.t()) ::
          {:ok, list(result_row())} | {:error, Exception.t()}
  defp run_query(tsv_query, repo) do
    case SQL.query(repo, tsv_query, []) do
      {:ok, result} ->
        {:ok,
         result.rows
         |> Enum.map(fn [name, value, label, count] ->
           {name, value, if(label != "", do: label, else: nil), count}
         end)}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec consolidate_facet_results(
          module(),
          list(result_row()),
          list(result_row()),
          map(),
          facet_configs()
        ) ::
          list(Facet.t())
  defp consolidate_facet_results(
         module,
         all_facet_rows,
         filtered_facet_rows,
         search_params,
         facet_configs
       ) do
    prefix = Constants.facet_search_field_prefix()

    search_params_value_lookup =
      (search_params.filters || [])
      |> Enum.reduce(%{}, fn %{field: field, value: values}, acc ->
        Map.put(
          acc,
          field |> to_string() |> String.trim_leading(prefix),
          values
        )
      end)

    all_facet_result_states =
      create_facet_result_states(
        all_facet_rows,
        facet_configs,
        search_params_value_lookup
      )

    filtered_facet_result_states =
      create_facet_result_states(
        filtered_facet_rows,
        facet_configs,
        search_params_value_lookup
      )

    combined_facet_result_states =
      all_facet_result_states
      |> combine_facet_result_states(filtered_facet_result_states)
      |> process_hierarchies(search_params_value_lookup, facet_configs)

    create_facets(module, combined_facet_result_states, facet_configs)
  end

  @spec combine_facet_result_states(
          facet_result_states(),
          facet_result_states()
        ) :: facet_result_states()
  defp combine_facet_result_states(
         all_facet_result_states,
         filtered_facet_result_states
       )
       when filtered_facet_result_states == %{},
       do: all_facet_result_states

  defp combine_facet_result_states(
         all_facet_result_states,
         filtered_facet_result_states
       ) do
    # If any option in a group is selected, take all other options from all_facet_result_states
    filtered_facet_result_states
    |> Enum.reduce(%{}, fn {name, states}, acc ->
      states =
        if Enum.any?(states, &(&1.selected || &1.hierarchy)),
          do: merge_states(states, all_facet_result_states[name]),
          else: states

      Map.put(acc, name, states)
    end)
  end

  defp merge_states(filtered_result_states, all_result_states) do
    # Take all entries from all_result_states, but copy the counts of filtered_result_states
    count_by_value_lookup =
      Enum.reduce(filtered_result_states, %{}, fn state, acc ->
        Map.put(acc, state.value, state.count)
      end)

    all_result_states
    |> Enum.map(fn state ->
      count = count_by_value_lookup[state.value] || state.count
      Map.put(state, :count, count)
    end)
  end

  defp process_hierarchies(
         combined_facet_result_states,
         search_params_value_lookup,
         facet_configs
       ) do
    derived_parent_values =
      derive_parent_values(search_params_value_lookup, facet_configs)

    combined_facet_result_states
    |> auto_select_parent_values(derived_parent_values)
    |> only_keep_children_of_selected_parents(derived_parent_values)
  end

  defp derive_parent_values(search_params_value_lookup, facet_configs) do
    hierarchy_facet_configs =
      Enum.filter(facet_configs, fn {_name, config} -> !!config.hierarchy end)

    parent_lookup =
      hierarchy_facet_configs
      |> Enum.reduce(%{}, fn {name, config}, acc ->
        Map.put(acc, name, config.parent)
      end)

    hierarchy_facet_config_name_lookup =
      Enum.reduce(hierarchy_facet_configs, %{}, fn {name, _config}, acc ->
        Map.put(acc, to_string(name), true)
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
              Map.new([{name |> String.to_existing_atom(), value}]),
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
          facet_configs()
        ) :: list(Facet.t())
  defp create_facets(module, facet_result_states, facet_configs) do
    facet_result_states
    |> Enum.reduce([], fn
      {_field, states}, acc when states == [] ->
        acc

      {field, states}, acc ->
        facet_config = get_in(facet_configs, [Access.key(field)])
        options = Enum.map(states, &create_option(module, &1))

        if facet_config.hide_when_selected and Enum.any?(options, & &1.selected) do
          acc
        else
          [
            %Facet{
              field: field,
              parent: facet_config.parent,
              options: options
            }
            | acc
          ]
        end
    end)
    |> Enum.reverse()
  end

  @spec create_option(module(), facet_result_state()) :: Option.t()
  defp create_option(module, facet_result_state) do
    %{
      count: count,
      database_label: database_label,
      field: field,
      range_bucket_value: range_bucket_value,
      selected: selected,
      value: value
    } = facet_result_state

    has_option_label_callback =
      Kernel.function_exported?(module, Constants.option_label_callback(), 3)

    option_label =
      if has_option_label_callback do
        apply(module, Constants.option_label_callback(), [
          field,
          range_bucket_value || value,
          database_label
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
    facet_rows
    |> Enum.map(fn {name, raw_value, database_label, count} ->
      facet_config =
        get_in(facet_configs, [Access.key(String.to_existing_atom(name))])

      if is_nil(facet_config) do
        raise "FacetedSearch: facet_field '#{name}' is not configured."
      end

      value = cast_value(raw_value, facet_config)

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

  defp cast_value(raw_value, %{range_buckets: range_buckets} = _facet_config)
       when is_list(range_buckets) do
    # Get bucket number
    String.to_integer(raw_value)
  end

  defp cast_value(raw_value, facet_config) when not is_nil(facet_config) do
    case Ecto.Type.cast(facet_config.ecto_type, raw_value) do
      {:ok, value} -> value
      _ -> raw_value
    end
  end

  defp cast_value(raw_value, _), do: raw_value

  def clean_search_params(%{filters: filters} = _search_params),
    do: %{filters: filters}

  def clean_search_params(_), do: %{filters: []}
end
