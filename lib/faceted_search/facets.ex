defmodule FacetedSearch.Facets do
  @moduledoc false

  use FacetedSearch.Types,
    include: [:flop_adapter_options]

  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Adapters.SQL
  alias FacetedSearch.Config
  alias FacetedSearch.Facet
  alias FacetedSearch.FacetConfig
  alias FacetedSearch.FacetValue
  alias FacetedSearch.Filter

  @spec search(Ecto.Queryable.t(), map() | nil, [flop_adapter_option()]) ::
          {:ok, list(Facet.t())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
  def search(ecto_schema, search_params \\ %{}, flop_adapter_options \\ []) do
    repo = Keyword.get(flop_adapter_options, :repo, Config.get_repo(flop_adapter_options))
    {_view_name, module} = ecto_schema
    search_view_description = FacetedSearch.search_view_description(module)
    facet_configs = FacetConfig.facet_configs(search_view_description)
    opts = Keyword.put(flop_adapter_options, :for, module)

    search_params_for_all_facets =
      create_search_params_for_all_facets(search_params, facet_configs)

    with {:ok, all_facet_rows} <-
           get_facet_results(repo, ecto_schema, search_params_for_all_facets, opts),
         {:ok, filtered_facet_rows} <-
           get_facet_results(repo, ecto_schema, search_params, opts) do
      facet_results =
        consolidate_facet_results(
          all_facet_rows,
          filtered_facet_rows,
          search_params,
          facet_configs
        )

      {:ok, facet_results}
    else
      error ->
        error
    end
  end

  @spec create_search_params_for_all_facets(map(), %{atom() => FacetConfig.t()}) :: map()
  defp create_search_params_for_all_facets(%{filters: filters} = search_params, facet_configs)
       when is_list(filters) do
    facet_fields =
      Map.keys(facet_configs) |> Enum.map(&"#{Filter.facet_search_field_prefix()}#{&1}")

    update_in(search_params, [:filters], fn filters ->
      Enum.filter(filters, &(to_string(&1.field) not in facet_fields))
    end)
  end

  defp create_search_params_for_all_facets(search_params, _facet_configs), do: search_params

  @spec get_facet_results(Ecto.Repo.t(), Ecto.Queryable.t(), map(), Keyword.t()) ::
          {:ok, list(result_row())} | {:error, Flop.Meta.t()} | {:error, Exception.t()}
  defp get_facet_results(repo, ecto_schema, search_params, opts) do
    case Flop.validate(search_params, opts) do
      {:ok, flop} ->
        ecto_schema
        |> create_query(repo, flop, opts)
        |> run_query(repo)

      {:error, meta} ->
        {:error, meta}
    end
  end

  @spec create_query(Ecto.Queryable.t(), Ecto.Repo.t(), Flop.t(), Keyword.t()) :: String.t()
  defp create_query(ecto_schema, repo, flop, opts) do
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

    """
    SELECT
      split_part(word, ':', 1) AS attr,
      split_part(word, ':', 2) AS value,
      ndoc AS count
    FROM ts_stat($$
      #{sql_with_variables}
    $$)
    ORDER BY word;
    """
  end

  @typep result_row :: {String.t(), String.t(), integer()}

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec run_query(String.t(), Ecto.Repo.t()) ::
          {:ok, list(result_row())} | {:error, Exception.t()}
  defp run_query(tsv_query, repo) do
    case SQL.query(repo, tsv_query, []) do
      {:ok, result} ->
        {:ok, result.rows |> Enum.map(fn [name, value, count] -> {name, value, count} end)}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec consolidate_facet_results(list(result_row()), list(result_row()), map(), %{
          atom() => FacetConfig.t()
        }) ::
          list(result_row())
  defp consolidate_facet_results(
         all_facet_rows,
         filtered_facet_rows,
         search_params,
         facet_configs
       ) do
    filtered_facet_groups =
      filtered_facet_rows
      |> Enum.group_by(fn {name, _value, _count} -> name end)

    filtered_facet_keys = Map.keys(filtered_facet_groups)
    search_params_value_lookup = create_search_params_value_lookup(search_params)

    all_facet_rows
    |> Enum.group_by(fn {name, _value, _count} -> name end)
    |> Enum.filter(fn {key, _} -> key in filtered_facet_keys end)
    |> Enum.map(fn {_key, result_rows} ->
      cast_to_facet_list(result_rows, facet_configs, search_params_value_lookup)
    end)
  end

  @spec create_search_params_value_lookup(map()) :: %{String.t() => boolean()}
  defp create_search_params_value_lookup(%{filters: filters} = search_params)
       when is_list(filters) do
    search_params.filters
    |> Enum.map(&{to_string(&1.field), &1.value})
    |> Enum.filter(fn {field_name, _} ->
      String.starts_with?(field_name, Filter.facet_search_field_prefix())
    end)
    |> Enum.reduce(%{}, fn {field_name, param_values}, acc ->
      original_field_name = String.trim_leading(field_name, Filter.facet_search_field_prefix())
      string_values = Enum.map(param_values, &to_string/1)
      Map.update(acc, original_field_name, string_values, fn values -> values ++ values end)
    end)
  end

  defp create_search_params_value_lookup(_search_params), do: %{}

  @spec cast_to_facet_list(
          list(result_row()),
          %{
            atom() => FacetConfig.t()
          },
          map()
        ) :: list(Facet.t())
  defp cast_to_facet_list(result_rows, facet_configs, search_params_value_lookup) do
    result_rows
    |> Enum.group_by(fn {name, _value, _count} -> name end)
    |> Enum.reduce([], fn {name, result_rows}, acc ->
      facet = %Facet{
        type: "value",
        field: String.to_existing_atom(name),
        facet_values:
          create_facet_values(
            result_rows,
            get_in(facet_configs, [Access.key(String.to_existing_atom(name))]),
            search_params_value_lookup
          )
      }

      [facet | acc]
    end)
  end

  @spec create_facet_values(list(result_row()), FacetConfig.t() | nil, map()) ::
          list(Facet.t())
  defp create_facet_values(facet_results, facet_config, search_params_value_lookup) do
    Enum.map(facet_results, fn {name, raw_value, count} ->
      %FacetValue{
        value: cast_value(raw_value, facet_config),
        count: count,
        selected:
          !!search_params_value_lookup[name] and raw_value in search_params_value_lookup[name]
      }
    end)
  end

  defp cast_value(raw_value, facet_config) when not is_nil(facet_config) do
    case Ecto.Type.cast(facet_config.ecto_type, raw_value) do
      {:ok, value} -> value
      _ -> raw_value
    end
  end

  defp cast_value(raw_value, _), do: raw_value
end
