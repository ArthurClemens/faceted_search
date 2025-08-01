defmodule FacetedSearch.Cache do
  @moduledoc false

  use GenServer, restart: :transient

  require Logger

  @ets_settings [:set, :protected, :named_table]

  ## Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    cache_id = Keyword.get(opts, :cache_id, __MODULE__)
    GenServer.start_link(__MODULE__, cache_id, name: name)
  end

  def get(instance \\ __MODULE__, view_name, cache_key) do
    GenServer.call(instance, {:get, view_name, cache_key})
  end

  def insert(instance \\ __MODULE__, view_name, cache_key, data) do
    GenServer.cast(instance, {:insert, view_name, cache_key, data})
  end

  def clear(instance \\ __MODULE__, view_name) do
    GenServer.cast(instance, {:clear, view_name})
  end

  def delete(instance \\ __MODULE__) do
    GenServer.cast(instance, {:delete})
  end

  ## Server API

  def init(cache_id) do
    table = :ets.new(cache_id, @ets_settings)
    {:ok, table}
  end

  def handle_call({:get, view_name, data_key}, _from, table) do
    result =
      ets_lookup(table, view_name, data_key)
      |> tap(fn
        {:ok, _} -> Logger.debug("FacetedSearch.Cache.get/3: data read from cache")
        {:error, :no_cache} -> Logger.debug("FacetedSearch.Cache.get/3: no cache")
      end)

    {:reply, result, table}
  end

  def handle_cast({:insert, view_name, data_key, data}, table) do
    ets_insert(table, view_name, data_key, data)
    |> tap(fn
      _ ->
        Logger.debug("FacetedSearch.Cache.insert/4: data written to cache")
    end)

    {:noreply, table}
  end

  def handle_cast({:clear, view_name}, table) do
    ets_delete(table, view_name)
    |> tap(fn _ ->
      Logger.debug("FacetedSearch.Cache.clear/2: cache cleared for view: #{view_name}")
    end)

    {:noreply, table}
  end

  def handle_cast({:delete}, table) do
    ets_delete(table)
    |> tap(fn _ ->
      Logger.debug("FacetedSearch.Cache.clear/2: cache deleted")
    end)

    {:noreply, nil}
  end

  defp ets_insert(table, view_name, data_key, data) do
    :ets.insert(table, {cache_key(view_name, data_key), data})
  end

  defp ets_lookup(table, view_name, data_key) do
    case :ets.lookup(table, cache_key(view_name, data_key)) do
      [] ->
        {:error, :no_cache}

      [{_, data}] ->
        {:ok, data}
    end
  end

  defp ets_delete(table) do
    :ets.delete(table)
  end

  defp ets_delete(table, view_name) do
    :ets.match_delete(table, {{view_name, :_}, :_})
  end

  defp cache_key(view_name, data_key), do: {view_name, data_key}
end
