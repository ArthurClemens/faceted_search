defmodule Fase.Facets.FacetSearch do
  @moduledoc false

  use Fase.Internal.Types,
    include: [:facet_search_options, :search]

  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Adapters.SQL
  alias Fase.Internal.Constants
  alias Fase.Internal.FacetConfig
  alias Fase.SearchView.Config

  # search_facets
  # Gets results for each facet, where all filters are applied except for that facet.
  # Performs a facet query for each field in search param filters, where the filter for
  # that field is omitted.

  @spec search_facets(Ecto.Queryable.t(), map(), facet_configs(), [
          facet_search_option()
        ]) ::
          {:ok, list(result_row())} | {:error, Exception.t()}
  def search_facets(
        ecto_schema,
        search_params,
        facet_configs,
        facet_search_options
      ) do
    repo =
      Keyword.get(
        facet_search_options,
        :repo,
        Config.get_repo(facet_search_options)
      )

    {_view_name, module} = ecto_schema

    opts = Keyword.put(facet_search_options, :for, module)

    create_stratified_query(
      repo,
      ecto_schema,
      search_params,
      facet_configs,
      opts
    )
    |> run_query(repo)
  end

  # Creates a single query that contains sub queries for each facet.

  @spec create_stratified_query(
          Ecto.Repo.t(),
          Ecto.Queryable.t(),
          map(),
          facet_configs(),
          Keyword.t()
        ) ::
          String.t()
  defp create_stratified_query(
         repo,
         ecto_schema,
         search_params,
         facet_configs,
         opts
       ) do
    base_query =
      search_params
      |> create_search_params_without_facets(facet_configs)
      |> params_to_query(repo, ecto_schema, opts)

    facet_configs
    |> Enum.reduce([], fn {_, facet_config}, acc ->
      current_filters =
        search_params.filters
        |> Enum.filter(&(&1.field != facet_config.filter_field))

      current_search_params =
        Map.replace(search_params, :filters, current_filters)

      query = params_to_query(current_search_params, repo, ecto_schema, opts)

      if query do
        [{facet_config.name, query} | acc]
      else
        acc
      end
    end)
    |> combine_stratified_queries(base_query)
  end

  defp params_to_query(params, repo, ecto_schema, opts) do
    case Flop.validate(params, opts) do
      {:ok, flop} ->
        create_single_facet_query(repo, ecto_schema, flop, opts)

      {:error, meta} ->
        Logger.error("Invalid params #{inspect(params)}: #{inspect(meta)}")
        nil
    end
  end

  @spec combine_stratified_queries(list(String.t()), String.t()) :: String.t()
  defp combine_stratified_queries(facet_queries, base_query) do
    if facet_queries == [] do
      tsv_single_query(base_query) |> tsv_query()
    else
      separator = """
      UNION
      """

      Enum.map_join(facet_queries, separator, fn {name, query} ->
        tsv_single_query(query, name)
      end)
      |> tsv_query()
    end
  end

  defp tsv_query(query) do
    """
    #{query}
    ORDER BY attr, value
    """
  end

  defp tsv_single_query(inner_query, filter_on_name \\ nil) do
    where_clause =
      if filter_on_name, do: "\nWHERE t.attr = '#{filter_on_name}'", else: ""

    separator = Constants.facet_separator()

    """
    (
      SELECT *
      FROM (
        SELECT
          split_part(word, '#{separator}', 1) AS attr,
          split_part(word, '#{separator}', 2) AS value,
          split_part(word, '#{separator}', 3) AS label,
          ndoc AS count
        FROM ts_stat($$
          #{inner_query}
        $$)
      ) t #{where_clause}
    )
    """
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

  @spec create_single_facet_query(
          Ecto.Repo.t(),
          Ecto.Queryable.t(),
          Flop.t(),
          Keyword.t()
        ) ::
          String.t()
  defp create_single_facet_query(repo, ecto_schema, flop, opts) do
    query_opts = Keyword.get(opts, :query_opts, [])
    prefix = Keyword.get(query_opts, :prefix, nil)

    query =
      from(ecto_schema, as: :document, prefix: ^prefix)
      |> Flop.filter(flop, opts)
      |> select([document: document], document.id)
      |> exclude(:limit)
      |> exclude(:order_by)

    {sql, params} = repo.to_sql(:all, query)

    sql_with_tsv = String.replace(sql, ~s("id"), ~s("facet"))

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
  end

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec run_query(String.t(), Ecto.Repo.t()) ::
          {:ok, list(result_row())} | {:error, Exception.t()}
  defp run_query(query, repo) do
    case SQL.query(repo, query, []) do
      {:ok, result} ->
        {:ok,
         result.rows
         |> Enum.map(fn [name, value, label, count] ->
           {name, value, if(label == "", do: nil, else: label), count}
         end)}

      {:error, error} ->
        {:error, error}
    end
  end

  def cast_value(raw_value, %{range_buckets: range_buckets} = _facet_config)
      when is_binary(raw_value) and is_list(range_buckets) do
    # Get bucket number
    String.to_integer(raw_value)
  end

  def cast_value(raw_value, facet_config) when not is_nil(facet_config) do
    case Ecto.Type.cast(facet_config.ecto_type, raw_value) do
      {:ok, value} -> value
      _ -> raw_value
    end
  end

  def cast_value(raw_value, _), do: raw_value

  # normalize_search_params
  # Search params may be a string map (from form inputs) or atom map (from code).
  # Filter values may be strings, these are cast using the ecto_types defined in facet configs.

  def normalize_search_params(raw_search_params, module) do
    case raw_search_params
         |> Flop.Validation.changeset([])
         |> Ecto.Changeset.apply_action(:replace) do
      {:ok, flop} ->
        search_view_description = Fase.search_view_description(module)
        facet_configs = FacetConfig.facet_configs(search_view_description)

        facet_configs_string_map =
          Enum.reduce(facet_configs, %{}, fn {key, value}, acc ->
            Map.put(acc, to_string(key), value)
          end)

        filters =
          Enum.map(
            flop.filters,
            &normalize_filter(&1, facet_configs_string_map)
          )

        %{filters: filters}

      _ ->
        %{filters: []}
    end
  end

  # Convert a Flop.Filter struct to a map.
  # Cast facet values using the ecto_types defined in facet configs.
  defp normalize_filter(filter, facet_configs_string_map) do
    filter_map = Map.from_struct(filter)

    field_name_string = filter_map.field |> to_string()
    prefix = Constants.facet_search_field_prefix()

    if String.starts_with?(field_name_string, prefix) do
      field_name_without_facet_prefix =
        String.replace_prefix(field_name_string, prefix, "")

      facet_config =
        facet_configs_string_map[field_name_without_facet_prefix]

      cast_value = Enum.map(filter_map.value, &cast_value(&1, facet_config))
      Map.replace(filter_map, :value, cast_value)
    else
      filter_map
    end
  end
end
