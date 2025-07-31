defmodule FacetedSearch.FacetsCache do
  @moduledoc false

  require Logger

  @ets_settings [:set, :public, :named_table]
  @cache_id :facet_results

  def get(view_name, data_key) do
    case :ets.whereis(@cache_id) do
      :undefined -> {:error, :no_table}
      _table -> lookup(view_name, data_key)
    end
  end

  defp lookup(view_name, filters) do
    case :ets.lookup(@cache_id, cache_key(view_name, filters)) do
      [] ->
        Logger.debug("FacetedSearch FacetsCache.lookup/2: no cache")
        {:error, :no_cache}

      [{_, data}] ->
        Logger.debug("FacetedSearch FacetsCache.lookup/2: data read from cache")
        {:ok, data}
    end
  end

  def set(view_name, data_key, data) do
    table = get_or_create_table()
    :ets.insert(table, {cache_key(view_name, data_key), data})

    case get(view_name, data_key) do
      {:error, :no_table} ->
        Logger.debug(
          "FacetedSearch FacetsCache.set/3: error inserting data in table, table: #{table}"
        )

        {:error, false}

      _ ->
        Logger.debug("FacetedSearch FacetsCache.set/3: data stored in cache, table: #{table}")
        {:ok, true}
    end
  end

  def set_with_fun(view_name, data_key, fun) do
    case fun.() do
      {:ok, data} ->
        set(view_name, data_key, data)
        {:ok, data}

      error ->
        error
    end
  end

  @spec clear(String.t()) :: {:ok, String.t()} | {:error, :no_table}
  def clear(view_name) do
    case :ets.whereis(@cache_id) do
      :undefined ->
        {:error, :no_table}

      table ->
        Logger.debug("FacetedSearch FacetsCache.clear/1: cache cleared")
        :ets.match_delete(table, {{view_name, :_}, :_})
        {:ok, view_name}
    end
  end

  defp get_or_create_table do
    case :ets.whereis(@cache_id) do
      :undefined ->
        :ets.new(@cache_id, @ets_settings)

      table ->
        table
    end
  end

  defp cache_key(view_name, filters), do: {view_name, filters}
end
