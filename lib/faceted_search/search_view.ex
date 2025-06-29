defmodule FacetedSearch.SearchView do
  @moduledoc false

  use FacetedSearch.Types,
    include: [:schema_options, :create_search_view_options]

  require Logger

  alias Ecto.Adapters.SQL
  alias FacetedSearch.Config
  alias FacetedSearch.Errors.SearchViewError
  alias FacetedSearch.Field
  alias FacetedSearch.Join
  alias FacetedSearch.SearchViewDescription
  alias FacetedSearch.Source

  @scope_func :scope_by

  @doc """
  The normalized Postgres view name generated from `view_id`.
  """
  @spec search_view_name(String.t()) :: String.t()
  def search_view_name(view_id), do: Config.new(view_id).view_name_with_prefix

  @spec create_search_view_description(schema_options()) :: SearchViewDescription.t()
  def create_search_view_description(options), do: SearchViewDescription.new(options)

  @doc """
  Creates a Postgres view that collects data for searching.
  If the seach view already exists, it will be dropped first.
  """
  @spec create_search_view(schema_options(), String.t(), [create_search_view_option()]) ::
          {:ok, String.t()} | {:error, term()}
  def create_search_view(options, view_id, opts \\ []) do
    %{view_name_with_prefix: view_name_with_prefix} = config = Config.new(view_id, opts)

    search_view_description = create_search_view_description(options)

    if search_view_exists?(view_id, opts) do
      delete_search_view(view_id, opts)
    end

    case build_search_view(search_view_description, config) do
      :ok ->
        Logger.info("FacetedSearch: search view '#{view_name_with_prefix}' created")
        refresh_search_view(view_id, opts)

      {:error, error} ->
        raise SearchViewError, %{error: error, view_name: view_name_with_prefix}
    end
  end

  @doc """
  Creates the Postgres view if it does not exist.
  """
  @spec create_search_view_if_not_exists(schema_options(), String.t(), [
          create_search_view_option()
        ]) ::
          {:ok, String.t()} | {:error, term()}
  def create_search_view_if_not_exists(options, view_id, opts \\ []) do
    if search_view_exists?(view_id, opts) do
      {:ok, view_id}
    else
      create_search_view(options, view_id, opts)
    end
  end

  @doc """
  Refreshes the search view.
  """
  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec refresh_search_view(String.t(), [create_search_view_option()]) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def refresh_search_view(view_id, opts) do
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} = Config.new(view_id, opts)

    sql = """
    REFRESH MATERIALIZED VIEW #{view_name_with_prefix};
    """

    case SQL.query(repo, sql, []) do
      {:ok, _result} ->
        Logger.info("FacetedSearch: search view '#{view_name_with_prefix}' refreshed")
        {:ok, view_id}

      {:error, error} ->
        Logger.error(
          "FacetedSearch: search view '#{view_name_with_prefix}' could not be refreshed"
        )

        {:error, error}
    end
  end

  @doc """
  Drops the search view.
  """
  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec drop_search_view(String.t(), [create_search_view_option()]) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def drop_search_view(view_id, opts) do
    if search_view_exists?(view_id, opts) do
      delete_search_view(view_id, opts)
    else
      {:ok, view_id}
    end
  end

  defp delete_search_view(view_id, opts) do
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} = Config.new(view_id, opts)

    sql = """
    DROP MATERIALIZED VIEW #{view_name_with_prefix};
    """

    case SQL.query(repo, sql, []) do
      {:ok, _result} ->
        Logger.info("FacetedSearch: search view '#{view_name_with_prefix}' dropped")
        {:ok, view_id}

      {:error, error} ->
        Logger.error("FacetedSearch: search view '#{view_name_with_prefix}' could not be dropped")

        {:error, error}
    end
  end

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec search_view_exists?(String.t(), [create_search_view_option()]) :: boolean()
  defp search_view_exists?(view_id, opts) do
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} = Config.new(view_id, opts)

    sql = """
    SELECT id FROM #{view_name_with_prefix}
    LIMIT 1;
    """

    case SQL.query(repo, sql, []) do
      {:ok, result} ->
        result != []

      {:error, _error} ->
        false
    end
  end

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  defp build_search_view(search_view_description, config) do
    %{view_name: view_name, view_name_with_prefix: view_name_with_prefix, repo: repo} = config

    drop_data_index_sql = """
    DROP INDEX IF EXISTS #{view_name_with_prefix}_data_idx
    """

    drop_text_index_sql = """
    DROP INDEX IF EXISTS #{view_name_with_prefix}_text_idx
    """

    drop_gin_index_sql = """
    DROP INDEX IF EXISTS #{view_name_with_prefix}_tsv_gin_idx
    """

    drop_view_sql = """
    DROP MATERIALIZED VIEW IF EXISTS #{view_name_with_prefix};
    """

    create_view_sql = """
    CREATE MATERIALIZED VIEW #{view_name_with_prefix}
    AS

    #{build_search_view_columns(search_view_description, config)}

    WITH NO DATA;
    """

    create_data_index_sql = """
    CREATE INDEX #{view_name}_data_idx
    ON #{view_name_with_prefix}
    USING gin(to_tsvector('simple', data))
    """

    create_text_index_sql = """
    CREATE INDEX #{view_name}_text_idx
    ON #{view_name_with_prefix}
    USING gin(to_tsvector('simple', text))
    """

    create_gin_index_sql = """
    CREATE INDEX #{view_name}_tsv_gin_idx
    ON #{view_name_with_prefix}
    USING gin(tsv)
    """

    result =
      [
        drop_data_index_sql,
        drop_text_index_sql,
        drop_gin_index_sql,
        drop_view_sql,
        create_view_sql,
        create_data_index_sql,
        create_text_index_sql,
        create_gin_index_sql
      ]
      |> Enum.reduce(%{errors: []}, fn sql, acc ->
        case SQL.query(repo, sql, []) do
          {:ok, _} ->
            acc

          {:error, error} ->
            Map.update(acc, :errors, [], fn errors -> [error | errors] end)
        end
      end)

    if result.errors != [] do
      {:error, result.errors |> Enum.reverse() |> List.first()}
    else
      :ok
    end
  end

  defp build_search_view_columns(search_view_description, config) do
    Enum.map_join(
      search_view_description.sources,
      "\n\nUNION\n\n",
      &columns_from_source(&1, config, search_view_description)
    )
  end

  defp columns_from_source(source, config, search_view_description) do
    %{table_name: table_name, prefix: prefix} = source
    table_name_with_prefix = table_name_with_prefix(table_name, prefix)

    columns =
      [
        &create_id_columns/2,
        &create_data_column/2,
        &create_text_column/2,
        &create_tsv_column/2,
        &create_date_columns/2,
        &create_sort_columns/2
      ]
      |> Enum.filter(&(not is_nil(&1) and &1 != ""))
      |> Enum.map(&apply(&1, [source, search_view_description]))
      |> Enum.filter(&(not is_nil(&1) and &1 != ""))
      |> Enum.map_join(",\n", &String.trim/1)

    joins = create_joins(source)
    where_filters = create_where_filters(source, config)

    [
      "SELECT",
      columns,
      "FROM #{table_name_with_prefix}",
      joins,
      where_filters,
      "GROUP BY #{table_name}.id"
    ]
    |> Enum.filter(&(!!&1))
    |> Enum.map_join("\n", &String.trim/1)
  end

  defp create_joins(%{joins: joins} = source) when is_list(joins) and joins != [] do
    source.joins
    |> Enum.map_join("\n", fn join ->
      %{table: table_name, on: on, as: as, prefix: prefix} = join
      table_name_with_prefix = table_name_with_prefix(table_name, prefix)
      left_join = "LEFT JOIN #{table_name_with_prefix}"
      as = if as, do: "AS #{as}", else: nil
      on = if on, do: "ON #{on}", else: nil

      [
        left_join,
        as,
        on
      ]
      |> Enum.filter(&(!!&1))
      |> Enum.join(" ")
    end)
  end

  defp create_joins(_source), do: nil

  defp create_where_filters(
         %{scopes: scopes, table_name: table_name} = _source,
         %{current_scope: current_scope} = _config
       )
       when is_list(scopes) and scopes != [] and not is_nil(current_scope) do
    filters =
      scopes
      |> Enum.map_join(" AND ", &create_where_filter(&1, table_name, current_scope))

    """
    WHERE #{filters}
    """
  end

  defp create_where_filters(_source, _config), do: nil

  defp create_where_filter(scope, table_name, current_scope) do
    %{key: key, module: module} = scope

    if module.__info__(:attributes)
       |> Keyword.filter(fn {key, val} -> key == :behaviour and FacetedSearch in val end)
       |> Enum.empty?() do
      raise SearchViewError, %{error: "Missing behaviour scope_by", module: module}
    end

    scope_by_result = apply(module, @scope_func, [key, current_scope])

    %{
      field: field,
      comparison: comparison,
      value: value
    } = scope_by_result

    table_name = scope_by_result[:table] || table_name
    table_and_column = table_and_column_string(table_name, field)

    """
    #{table_and_column} #{comparison} '#{value}'
    """
  end

  @spec create_id_columns(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_id_columns(source, _search_view_description) do
    %{table_name: table_name} = source

    """
    CAST(#{table_name}.id AS text) AS id,
    '#{table_name}' AS source
    """
  end

  @spec create_data_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_data_column(
         %{fields: fields, data_fields: data_fields, joins: joins} = _source,
         _search_view_description
       )
       when is_list(fields) and fields != [] do
    object_string =
      fields
      |> Enum.filter(&(&1.name in data_fields))
      |> Enum.map_join(", ", fn field ->
        %{name: name, ecto_type: ecto_type} = field
        {table_name, column_name} = get_table_and_column(field, joins)
        table_and_column = table_and_column_string(table_name, column_name)

        case ecto_type do
          {:array, _} -> "'#{name}', array_agg(DISTINCT #{table_and_column})"
          :string -> "'#{name}', string_agg(DISTINCT #{table_and_column}, ', ')"
          _ -> "'#{name}', #{table_and_column}"
        end
      end)

    "jsonb_build_object(#{object_string}) AS data"
  end

  defp create_data_column(_, _), do: "NULL::jsonb AS data"

  @spec create_text_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_text_column(
         %{fields: fields, text_fields: text_fields, joins: joins} = _source,
         _search_view_description
       )
       when is_list(text_fields) and text_fields != [] do
    fields_array =
      fields
      |> Enum.filter(&(&1.name in text_fields))
      |> Enum.map_join(",\n", fn field ->
        {table_name, column_name} = get_table_and_column(field, joins)
        table_and_column = table_and_column_string(table_name, column_name)

        case field.ecto_type do
          :string -> "  COALESCE(string_agg(DISTINCT #{table_and_column}, ', '), '')"
          _ -> "  COALESCE(cast(#{table_and_column} AS text), '')"
        end
      end)

    """
    REPLACE(array_to_string(array[
    #{fields_array}
    ], ' '), '  ', ' ') AS text
    """
  end

  defp create_text_column(_, _), do: "NULL::text AS text"

  @spec create_tsv_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_tsv_column(
         %{fields: fields, facet_fields: facet_fields, joins: joins} = _source,
         _search_view_description
       )
       when is_list(facet_fields) and facet_fields != [] do
    fields
    |> Enum.filter(&(&1.name in facet_fields))
    |> Enum.map_join(", ", fn field ->
      %{name: name} = field

      {table_name, column_name} = get_table_and_column(field, joins)
      table_and_column = table_and_column_string(table_name, column_name)

      "'#{name}' || ':' || #{table_and_column}"
    end)
    |> tsv_column_wrap()
  end

  defp create_tsv_column(_, _), do: "NULL::tsvector AS tsv"

  defp tsv_column_wrap(key_values) do
    """
    array_to_tsvector(
      array_agg(array_remove(ARRAY[#{key_values}], NULL)) FILTER (WHERE array_remove(ARRAY[#{key_values}], NULL) <> '{}')
    ) AS tsv
    """
  end

  @spec create_date_columns(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_date_columns(%{table_name: table_name} = _source, _search_view_description) do
    """
    #{table_name}.inserted_at AS inserted_at,
    #{table_name}.updated_at AS updated_at
    """
  end

  @spec create_sort_columns(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_sort_columns(
         %{
           table_name: current_source_table_name,
           fields: fields,
           joins: joins,
           sort_fields: sort_fields
         },
         search_view_description
       )
       when is_list(fields) and fields != [] do
    all_fields = get_all_fields(search_view_description)
    all_sort_fields = get_all_sort_fields(search_view_description)

    current_source_sort_fields = sort_fields || []

    all_fields
    |> Enum.filter(&(&1.name in all_sort_fields))
    |> Enum.sort_by(fn
      %{table_name: table_name} = _field when table_name == current_source_table_name -> 0
      _field -> 1
    end)
    |> Enum.reduce(%{visited: %{}, instructions: []}, fn field, acc ->
      %{name: name, ecto_type: ecto_type} = field
      visited_id = "#{current_source_table_name}-#{name}"

      if acc.visited[visited_id] do
        acc
      else
        instruction =
          get_sort_instruction(%{
            current_source_sort_fields: current_source_sort_fields,
            current_source_table_name: current_source_table_name,
            ecto_type: ecto_type,
            field: field,
            joins: joins,
            name: name
          })

        %{
          visited: Map.put(acc.visited, visited_id, true),
          instructions: [instruction | acc.instructions]
        }
      end
    end)
    |> Map.get(:instructions)
    |> Enum.join(",\n")
  end

  defp create_sort_columns(_, _), do: nil

  def get_sort_instruction(attrs) do
    %{
      current_source_sort_fields: current_source_sort_fields,
      current_source_table_name: current_source_table_name,
      ecto_type: ecto_type,
      field: field,
      joins: joins,
      name: name
    } = attrs

    sort_column_name = "sort_#{name}"

    if field.name in current_source_sort_fields do
      {table_name, column_name} = get_table_and_column(field, joins)
      table_and_column = table_and_column_string(table_name, column_name)

      needs_aggregate = current_source_table_name != table_name

      ref =
        cond do
          is_tuple(ecto_type) and elem(ecto_type, 0) == :array ->
            "array_agg(DISTINCT #{table_and_column})"

          ecto_type == :string and needs_aggregate ->
            "COALESCE(string_agg(DISTINCT #{table_and_column}, ', '), '')"

          ecto_type == :boolean and needs_aggregate ->
            "every(#{table_and_column}.inactive)"

          needs_aggregate ->
            "any_value(#{table_and_column}.inactive)"

          true ->
            "#{table_and_column}"
        end

      "#{ref} AS #{sort_column_name}"
    else
      "NULL AS #{sort_column_name}"
    end
  end

  @spec get_table_and_column(Field.t(), list(Join.t() | nil)) :: {atom(), atom()}
  defp get_table_and_column(%Field{binding: binding} = field, joins)
       when is_list(joins) and joins != [] and not is_nil(binding) do
    %{binding: binding, field: join_field, table_name: table_name} = field
    join = Enum.find(joins, &(&1.as == binding || &1.table == binding))

    if join do
      {join.as || join.table, join_field}
    else
      {table_name, field.field}
    end
  end

  defp get_table_and_column(%Field{table_name: table_name, name: column_name}, _joins),
    do: {table_name, column_name}

  defp table_name_with_prefix(table_name, prefix) when is_binary(prefix),
    do: "#{prefix}.#{table_name}"

  defp table_name_with_prefix(table_name, _prefix), do: table_name

  defp table_and_column_string(table_name, column_name), do: "#{table_name}.#{column_name}"

  defp get_all_fields(search_view_description) do
    get_in(search_view_description, [
      Access.key(:sources),
      Access.all(),
      Access.key(:fields)
    ])
    |> List.flatten()
    |> Enum.filter(&(!!&1))
    |> Enum.uniq()
  end

  defp get_all_sort_fields(search_view_description) do
    get_in(search_view_description, [
      Access.key(:sources),
      Access.all(),
      Access.key(:sort_fields)
    ])
    |> List.flatten()
    |> Enum.filter(&(!!&1))
    |> Enum.uniq()
  end
end
