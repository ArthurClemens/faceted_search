defmodule FacetedSearch.SearchView do
  @moduledoc false

  use FacetedSearch.Types,
    include: [:schema_options, :create_search_view_options, :refresh_search_view_options]

  require Logger

  alias Ecto.Adapters.SQL
  alias FacetedSearch.Config
  alias FacetedSearch.DataField
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

    case build_search_view(search_view_description, config, opts) do
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
  @spec refresh_search_view(String.t(), [refresh_search_view_option()]) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def refresh_search_view(view_id, opts) do
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} = Config.new(view_id, opts)
    concurrently = Keyword.get(opts, :concurrently)

    params =
      [
        if(concurrently, do: "CONCURRENTLY", else: nil),
        view_name_with_prefix
      ]
      |> Enum.filter(&(!!&1))
      |> Enum.join(" ")

    sql = """
    REFRESH MATERIALIZED VIEW #{params};
    """

    case SQL.query(repo, sql, [], postgrex_options(opts)) do
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

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  defp delete_search_view(view_id, opts) do
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} = Config.new(view_id, opts)

    sql = """
    DROP MATERIALIZED VIEW #{view_name_with_prefix};
    """

    case SQL.query(repo, sql, [], postgrex_options(opts)) do
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

    case SQL.query(repo, sql, [], postgrex_options(opts)) do
      {:ok, result} ->
        result != []

      {:error, _error} ->
        false
    end
  end

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  defp build_search_view(search_view_description, config, opts) do
    %{view_name: view_name, view_name_with_prefix: view_name_with_prefix, repo: repo} = config

    create_pg_trgm_sql = "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    drop_indexes_sql = [
      (["id", "source", "data", "text", "tsv", "inserted_at", "updated_at"] ++
         get_sort_column_names(search_view_description))
      |> Enum.map(fn name ->
        """
        DROP INDEX CONCURRENTLY IF EXISTS #{view_name_with_prefix}_#{name}_idx
        """
      end)
    ]

    drop_view_sql = """
    DROP MATERIALIZED VIEW IF EXISTS #{view_name_with_prefix};
    """

    create_view_sql = """
    CREATE MATERIALIZED VIEW #{view_name_with_prefix}
    AS

    #{build_search_view_columns(search_view_description, config)}

    WITH NO DATA;
    """

    create_indexes_sql = [
      ([
         %{name: "id", unique: true},
         %{name: "source"},
         %{name: "data", using: "gin(data)"},
         %{name: "text", using: "gin(text gin_trgm_ops)"},
         %{name: "tsv", using: "gin(tsv)"},
         %{name: "inserted_at"},
         %{name: "updated_at"}
       ] ++
         (get_sort_column_names(search_view_description)
          |> Enum.map(&%{name: &1})))
      |> Enum.map(fn data ->
        name = data.name

        command = if data[:unique], do: "CREATE UNIQUE", else: "CREATE"

        on =
          if data[:using] do
            "ON #{view_name_with_prefix} USING #{data[:using]}"
          else
            "ON #{view_name_with_prefix}(#{name})"
          end

        """
        #{command} INDEX CONCURRENTLY #{view_name}_#{name}_idx
        #{on}
        """
      end)
    ]

    result =
      [
        create_pg_trgm_sql,
        drop_indexes_sql,
        drop_view_sql,
        create_view_sql,
        create_indexes_sql
      ]
      |> List.flatten()
      |> Enum.reduce(%{errors: []}, fn sql, acc ->
        case SQL.query(repo, sql, [], postgrex_options(opts)) do
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

  defp get_sort_column_names(search_view_description) do
    get_all_sort_fields(search_view_description)
    |> Enum.map(&"sort_#{&1.name}")
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
  defp create_id_columns(source, _) do
    %{table_name: table_name} = source

    """
    CAST(#{table_name}.id AS text) AS id,
    '#{table_name}' AS source
    """
  end

  @spec create_data_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_data_column(%{fields: fields, data_fields: data_fields} = source, _)
       when is_list(fields) and fields != [] and is_list(data_fields) and data_fields != [] do
    name_ref_data_column_entries = create_name_ref_data_column_entries(source)
    generated_data_column_entries = create_generated_data_column_entries(source)

    object_string =
      Enum.concat(name_ref_data_column_entries, generated_data_column_entries)
      |> Enum.filter(&(&1 != []))
      |> Enum.join(",\n#{line_indent(1)}")

    """
    jsonb_build_object(
    #{line_indent(1)}#{object_string}
    ) AS data
    """
  end

  defp create_data_column(_, _), do: "NULL::jsonb AS data"

  @spec create_name_ref_data_column_entries(Source.t()) :: list(String.t())
  defp create_name_ref_data_column_entries(
         %{fields: fields, data_fields: data_fields, joins: joins} = _source
       ) do
    data_field_name_lookup =
      Enum.reduce(data_fields, %{}, fn data_field, acc ->
        Map.put(acc, data_field.name, true)
      end)

    fields
    |> Enum.filter(&data_field_name_lookup[&1.name])
    |> Enum.map(&create_data_column_entry(&1, joins))
  end

  @spec create_data_column_entry(Field.t(), list(Join.t())) :: String.t()
  defp create_data_column_entry(field, joins) do
    %{name: name, ecto_type: ecto_type} = field
    {table_name, column_name} = get_table_and_column(field, joins)
    table_and_column = table_and_column_string(table_name, column_name)

    case ecto_type do
      {:array, _} -> "'#{name}', array_agg(DISTINCT #{table_and_column})"
      :string -> "'#{name}', string_agg(DISTINCT #{table_and_column}, ', ')"
      _ -> "'#{name}', #{table_and_column}"
    end
  end

  @spec create_generated_data_column_entries(Source.t()) :: list(String.t())
  defp create_generated_data_column_entries(source) do
    source.data_fields
    |> Enum.filter(&(not is_nil(&1.entries)))
    |> Enum.map(&create_generated_data_column_entry(&1, source))
  end

  @spec create_generated_data_column_entry(DataField.t(), Source.t()) :: String.t()
  defp create_generated_data_column_entry(
         %{name: name, entries: entries},
         %{fields: fields, joins: joins} = _source
       ) do
    table_and_columns =
      entries
      |> Enum.map(fn
        %{name: name, cast: cast, field_ref: field_ref} when not is_nil(field_ref) ->
          field = fields |> Enum.find(&(&1.name == field_ref))

          case get_table_and_column(field, joins) do
            {table_name, column_name} ->
              %{name: name, table_name: table_name, column_name: column_name, cast: cast}

            _ ->
              nil
          end

        %{name: name, cast: cast, binding: binding, field: field} ->
          %{name: name, table_name: binding, column_name: field, cast: cast}

        _ ->
          nil
      end)
      |> Enum.filter(&(!!&1))
      |> Enum.map(
        &Map.put(
          &1,
          :table_and_column,
          table_and_column_string(&1.table_name, &1.column_name) |> maybe_cast(&1.cast)
        )
      )

    key_values =
      table_and_columns
      |> Enum.map_join(
        ",\n#{line_indent(2)}",
        &"'#{&1.name}', #{&1.table_and_column}"
      )

    """
    '#{name}', json_agg(DISTINCT jsonb_build_object(
    #{line_indent(2)}#{key_values}
    #{line_indent(1)}))
    """
    |> String.trim()
  end

  defp line_indent(level) when level == 0, do: ""
  defp line_indent(level), do: "  " <> line_indent(level - 1)

  @spec create_text_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_text_column(%{fields: fields, text_fields: text_fields, joins: joins} = _source, _)
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
  defp create_tsv_column(%{fields: fields, facet_fields: facet_fields, joins: joins} = _source, _)
       when is_list(facet_fields) and facet_fields != [] do
    facet_fields
    |> Enum.reduce([], fn %{name: name, label_field: label_field}, acc ->
      field = Enum.find(fields, &(&1.name == name))
      label_field = Enum.find(fields, &(&1.name == label_field))

      if field do
        [%{field: field, label_field: label_field} | acc]
      else
        acc
      end
    end)
    |> Enum.map_join(", ", fn %{field: field, label_field: label_field} ->
      %{name: name} = field

      {table_name, column_name} = get_table_and_column(field, joins)
      table_and_column = table_and_column_string(table_name, column_name)

      label_table_and_column =
        if label_field do
          {label_table_name, label_column_name} = get_table_and_column(label_field, joins)
          table_and_column_string(label_table_name, label_column_name)
        else
          "''"
        end

      "'#{name}' || ':' || #{table_and_column} || ':' || #{label_table_and_column}"
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
  defp create_date_columns(%{table_name: table_name} = _source, _) do
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

    # We need to generate the same sort columns for every source:
    # listed in the same order and containing the same data types.

    combined_sort_fields =
      Enum.concat(sort_fields, get_all_sort_fields(search_view_description))
      |> Enum.uniq()

    current_source_sort_field_names = (sort_fields || []) |> Enum.map(& &1.name)

    combined_sort_fields
    |> Enum.map(
      &%{
        sort_field: &1,
        field:
          Enum.find(all_fields, fn field -> field.name == &1.name end)
          |> Map.put(:table_name, current_source_table_name)
      }
    )
    |> Enum.map_join(",\n", fn %{sort_field: sort_field, field: field} ->
      %{name: name, ecto_type: ecto_type} = field

      sort_column_name = "sort_#{name}"

      create_sort_statement(
        %{
          cast: sort_field.cast,
          current_source_table_name: current_source_table_name,
          ecto_type: ecto_type,
          field: field,
          joins: joins,
          sort_column_name: sort_column_name
        },
        field.name in current_source_sort_field_names
      )
    end)
  end

  defp create_sort_columns(_, _), do: nil

  defp create_sort_statement(attrs, field_in_current_source_sort_fields)
       when field_in_current_source_sort_fields do
    %{
      cast: cast,
      current_source_table_name: current_source_table_name,
      ecto_type: ecto_type,
      field: field,
      joins: joins,
      sort_column_name: sort_column_name
    } = attrs

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

    "#{ref |> maybe_cast(cast)} AS #{sort_column_name}"
  end

  defp create_sort_statement(
         %{
           sort_column_name: sort_column_name
         },
         _
       ) do
    "NULL AS #{sort_column_name}"
  end

  defp maybe_cast(value, cast) when not is_nil(cast), do: "CAST(#{value} AS #{cast})"
  defp maybe_cast(value, _cast), do: value

  @spec get_table_and_column(Field.t(), list(Join.t()) | nil) :: {atom(), atom()} | nil
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

  defp get_table_and_column(_, _), do: nil

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

  defp postgrex_options(opts) do
    [
      timeout: Keyword.get(opts, :timeout, nil),
      pool_timeout: Keyword.get(opts, :pool_timeout, nil)
    ]
    |> Enum.filter(fn {_, v} -> not is_nil(v) end)
  end
end
