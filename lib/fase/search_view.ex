defmodule Fase.SearchView do
  @moduledoc false

  use Fase.Internal.Types,
    include: [
      :schema_options,
      :create_search_view_options,
      :refresh_search_view_options
    ]

  require Logger

  alias Ecto.Adapters.SQL
  alias Fase.Errors.SearchViewError
  alias Fase.Internal.Constants
  alias Fase.SearchView.Config
  alias Fase.SearchView.DataField
  alias Fase.SearchView.FacetField
  alias Fase.SearchView.Field
  alias Fase.SearchView.Join
  alias Fase.SearchView.SearchViewDescription
  alias Fase.SearchView.Source

  @doc """
  The normalized Postgres view name generated from `view_id`.
  """
  @spec search_view_name(String.t()) :: String.t()
  def search_view_name(view_id), do: Config.new(view_id).view_name_with_prefix

  @spec create_search_view_description(schema_options()) ::
          SearchViewDescription.t()
  def create_search_view_description(options),
    do: SearchViewDescription.new(options)

  @doc """
  Creates a Postgres view that collects data for searching.
  If the seach view already exists, it will be dropped first.
  """
  @spec create_search_view(schema_options(), String.t(), [
          create_search_view_option()
        ]) ::
          {:ok, String.t()} | {:error, term()}
  def create_search_view(options, view_id, opts \\ []) do
    %{view_name_with_prefix: view_name_with_prefix} =
      config = Config.new(view_id, opts)

    search_view_description = create_search_view_description(options)

    if search_view_exists?(view_id, opts) do
      delete_search_view(view_id, opts)
    end

    case build_search_view(search_view_description, config, opts) do
      :ok ->
        Logger.info("Fase: search view '#{view_name_with_prefix}' created")

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
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} =
      Config.new(view_id, opts)

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
        Logger.info("Fase: search view '#{view_name_with_prefix}' refreshed")

        {:ok, view_id}

      {:error, error} ->
        Logger.error(
          "Fase: search view '#{view_name_with_prefix}' could not be refreshed"
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
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} =
      Config.new(view_id, opts)

    sql = """
    DROP MATERIALIZED VIEW #{view_name_with_prefix};
    """

    case SQL.query(repo, sql, [], postgrex_options(opts)) do
      {:ok, _result} ->
        Logger.info("Fase: search view '#{view_name_with_prefix}' dropped")

        {:ok, view_id}

      {:error, error} ->
        Logger.error(
          "Fase: search view '#{view_name_with_prefix}' could not be dropped"
        )

        {:error, error}
    end
  end

  # Skip warning: Query is not user-controlled.
  # sobelow_skip ["SQL.Query"]
  @spec search_view_exists?(String.t(), [create_search_view_option()]) ::
          boolean()
  def search_view_exists?(view_id, opts) do
    %{view_name_with_prefix: view_name_with_prefix, repo: repo} =
      Config.new(view_id, opts)

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
    %{
      view_name: view_name,
      view_name_with_prefix: view_name_with_prefix,
      repo: repo
    } = config

    create_pg_trgm_sql = "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    concurrent_index_cmd =
      if Application.get_env(:fase, :mode) == :test,
        do: "",
        else: "CONCURRENTLY"

    drop_indexes_sql = [
      ([
         "id",
         "source",
         "data",
         "text",
         "tsv"
       ] ++
         get_sort_column_names(search_view_description))
      |> Enum.map(fn name ->
        """
        DROP INDEX #{concurrent_index_cmd} IF EXISTS #{view_name_with_prefix}_#{name}_idx
        """
      end)
    ]

    drop_view_sql = """
    DROP MATERIALIZED VIEW IF EXISTS #{view_name_with_prefix};
    """

    create_view_sql =
      """
      CREATE MATERIALIZED VIEW #{view_name_with_prefix}
      AS

      #{build_search_view_columns(search_view_description, config)}

      WITH NO DATA;
      """
      |> String.trim()

    create_indexes_sql = [
      ([
         %{name: "id", unique: true},
         %{name: "source"},
         %{name: "data", using: "gin(data)"},
         %{name: "text", using: "gin(text gin_trgm_ops)"},
         %{name: "tsv", using: "gin(tsv)"}
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
        #{command} INDEX #{concurrent_index_cmd} #{view_name}_#{name}_idx
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
        &create_facet_column/2,
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
      "INNER JOIN source ON #{table_name}.id = source.id",
      where_filters,
      "GROUP BY #{table_name}.id"
    ]
    |> Enum.filter(&(!!&1))
    |> Enum.map_join("\n", &String.trim/1)
    |> wrap_with_source(table_name, table_name_with_prefix)
  end

  defp wrap_with_source(column_data, table_name, table_name_with_prefix) do
    """
    (
      WITH source AS (
        SELECT id, '#{table_name}' AS source_name
        FROM #{table_name_with_prefix}
      )
      #{column_data}
    )
    """
  end

  defp get_sort_column_names(search_view_description) do
    get_all_sort_fields(search_view_description)
    |> Enum.map(&"#{Constants.sort_field_prefix()}#{&1.name}")
  end

  # Joins

  defp create_joins(%{joins: joins} = source)
       when is_list(joins) and joins != [] do
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

  # Where filters

  defp create_where_filters(
         %{scope: scope} = source,
         %{current_scope: current_scope} = _config
       )
       when is_list(scope) and scope != [] and not is_nil(current_scope) do
    filters =
      scope
      |> Enum.map(&create_where_filter(&1, source, current_scope))
      |> Enum.filter(&(!!&1))
      |> Enum.join(" AND ")

    if filters != "" do
      """
      WHERE #{filters}
      """
    else
      nil
    end
  end

  defp create_where_filters(_source, _config), do: nil

  defp create_where_filter(scope, source, current_scope) do
    %{fields: fields, joins: joins, table_name: table_name} = source
    %{key: key, module: module} = scope

    if module.__info__(:attributes)
       |> Keyword.filter(fn {key, val} ->
         key == :behaviour and Fase in val
       end)
       |> Enum.empty?() do
      raise SearchViewError, %{
        error: "Missing behaviour scope_by",
        module: module
      }
    end

    scope_by_result =
      apply(module, Constants.scope_callback(), [key, current_scope])

    if scope_by_result do
      %{
        field: field_or_column_name,
        comparison: comparison,
        value: value
      } = scope_by_result

      field = Enum.find(fields, &(&1.name == field_or_column_name))

      table_and_column =
        if field do
          {table_name, column_name} = get_table_and_column(field, joins)
          table_and_column_string(table_name, column_name)
        else
          table_and_column_string(table_name, field_or_column_name)
        end

      """
      #{table_and_column} #{comparison} '#{value}'
      """
    else
      nil
    end
  end

  # ID columns

  @spec create_id_columns(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_id_columns(source, _) do
    %{table_name: table_name} = source

    [
      "#{table_name}.id AS id",
      "'#{table_name}' AS source"
    ]
    |> Enum.join(",\n")
  end

  # Data column

  @spec create_data_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_data_column(
         %{fields: fields, data_fields: data_fields} = source,
         _
       )
       when is_list(fields) and fields != [] and is_list(data_fields) and
              data_fields != [] do
    name_ref_data_column_entries = create_name_ref_data_column_entries(source)
    custom_data_entries = create_custom_data_entries(source)

    object_string =
      name_ref_data_column_entries
      |> Enum.concat(custom_data_entries)
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
         %{fields: fields, data_fields: data_fields} = source
       ) do
    data_field_name_lookup =
      Enum.reduce(data_fields, %{}, fn data_field, acc ->
        Map.put(acc, data_field.name, data_field)
      end)

    fields
    |> Enum.filter(&data_field_name_lookup[&1.name])
    |> Enum.map(
      &create_data_column_entry(&1, data_field_name_lookup[&1.name], source)
    )
  end

  @spec create_data_column_entry(Field.t(), DataField.t(), Source.t()) ::
          String.t()
  defp create_data_column_entry(field, data_field, %{
         joins: joins,
         table_name: current_source_table_name
       }) do
    %{name: name, ecto_type: ecto_type} = field

    {table_name, column_name} = get_table_and_column(field, joins)

    table_and_column =
      table_and_column_string(table_name, column_name)

    ecto_type = data_field.ecto_type || ecto_type

    value =
      (data_field.transforms || [])
      |> run_transforms(table_and_column)
      |> maybe_aggregate(
        current_source_table_name,
        table_name,
        ecto_type
      )

    "'#{name}', #{value}"
  end

  @spec create_custom_data_entries(Source.t()) :: list(String.t())
  defp create_custom_data_entries(source) do
    source.data_fields
    |> Enum.filter(&(not is_nil(&1.entries)))
    |> Enum.map(&create_custom_data_entry(&1, source))
  end

  @spec create_custom_data_entry(DataField.t(), Source.t()) :: String.t()
  defp create_custom_data_entry(
         %{name: name, entries: entries},
         %{fields: fields, joins: joins, table_name: current_source_table_name} =
           _source
       ) do
    entry_data =
      entries
      |> Enum.map(fn
        %{
          name: name,
          transforms: transforms,
          field_name: field_name,
          binding: binding,
          column: column
        } ->
          filter_fn =
            if is_nil(field_name) do
              fn field ->
                field.binding == binding and field.column == column
              end
            else
              fn field -> field.name == field_name end
            end

          field = fields |> Enum.find(&filter_fn.(&1))

          case get_table_and_column(field, joins) do
            {table_name, column_name} ->
              %{
                name: name,
                table_name: table_name,
                column_name: column_name,
                transforms: transforms,
                ecto_type: field.ecto_type
              }

            _ ->
              nil
          end

        _ ->
          nil
      end)
      |> Enum.filter(&(!!&1))
      |> Enum.map(fn entry ->
        value =
          run_transforms(
            entry.transforms,
            table_and_column_string(entry.table_name, entry.column_name)
          )
          |> maybe_aggregate(
            current_source_table_name,
            entry.table_name,
            entry.ecto_type
          )

        Map.put(
          entry,
          :table_and_column,
          value
        )
      end)

    key_values =
      entry_data
      |> Enum.map_join(
        ",\n#{line_indent(2)}",
        &"'#{&1.name}', #{&1.table_and_column}"
      )

    """
    '#{name}', jsonb_build_object(
    #{line_indent(2)}#{key_values}
    #{line_indent(1)})
    """
    |> String.trim()
  end

  # Text column

  @spec create_text_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_text_column(
         %{
           table_name: current_source_table_name,
           fields: fields,
           text_fields: text_fields,
           joins: joins
         } = _source,
         _
       )
       when is_list(text_fields) and text_fields != [] do
    fields_array =
      text_fields
      |> Enum.map(
        &%{
          text_field: &1,
          field:
            Enum.find(fields, fn field -> field.name == &1.name end)
            |> Map.put(:table_name, current_source_table_name)
        }
      )
      |> Enum.map_join(",\n", fn %{text_field: text_field, field: field} ->
        {table_name, column_name} = get_table_and_column(field, joins)
        table_and_column = table_and_column_string(table_name, column_name)

        default_transforms =
          case field.ecto_type do
            :string -> []
            _ -> ["CAST(? AS text)"]
          end

        custom_transforms = text_field.transforms || []

        Enum.concat(custom_transforms, default_transforms)
        |> run_transforms(table_and_column)
        |> maybe_aggregate(
          current_source_table_name,
          table_name,
          field.ecto_type
        )
      end)

    """
    REPLACE(array_to_string(array[
    #{fields_array}
    ], ' '), '  ', ' ') AS text
    """
  end

  defp create_text_column(_, _), do: "NULL::text AS text"

  # TSV column

  @spec create_facet_column(Source.t(), SearchViewDescription.t()) :: String.t()
  defp create_facet_column(%{facet_fields: facet_fields} = source, _)
       when is_list(facet_fields) and facet_fields != [] do
    facet_field_entries =
      facet_fields
      |> Enum.filter(&is_nil(&1.hierarchy))
      |> facet_field_entries(source)

    hierarchy_entries =
      facet_fields
      |> Enum.filter(&(not is_nil(&1.hierarchy)))
      |> hierarchy_entries(source)

    Enum.concat(facet_field_entries, hierarchy_entries)
    |> Enum.join(", ")
    |> facet_column_wrap()
  end

  defp create_facet_column(_, _), do: "NULL::tsvector AS tsv"

  defp facet_field_entries(
         facet_fields,
         %{fields: fields, joins: joins} = _source
       ) do
    facet_fields
    |> Enum.reduce([], fn %{
                            name: name,
                            label_field: label_field,
                            range_bounds: range_bounds
                          },
                          acc ->
      field = Enum.find(fields, &(&1.name == name))

      if field do
        label_field = Enum.find(fields, &(&1.name == label_field))

        [
          %{field: field, label_field: label_field, range_bounds: range_bounds}
          | acc
        ]
      else
        acc
      end
    end)
    |> Enum.map(fn %{
                     field: field,
                     label_field: label_field,
                     range_bounds: range_bounds
                   } ->
      %{name: name} = field

      {table_name, column_name} = get_table_and_column(field, joins)

      value =
        if range_bounds do
          table_and_column = table_and_column_string(table_name, column_name)
          create_width_bucket(table_and_column, range_bounds)
        else
          table_and_column_string(table_name, column_name)
        end

      label =
        if label_field do
          {label_table_name, label_column_name} =
            get_table_and_column(label_field, joins)

          table_and_column_string(label_table_name, label_column_name)
        else
          "''"
        end

      separator = Constants.facet_separator()

      "'#{name}' || '#{separator}' || #{value} || '#{separator}' || #{label}"
    end)
  end

  defp hierarchy_entries(facet_fields, source) do
    facet_fields
    |> Enum.map(fn facet_field ->
      %{name: name, value: value, label: label} =
        create_hierarchy_entry(facet_field, source)

      separator = Constants.facet_separator()

      "'#{name}' || '#{separator}' || #{value} || '#{separator}' || #{label}"
    end)
  end

  @spec create_hierarchy_entry(FacetField.t(), Source.t(), Keyword.t()) :: map()
  defp create_hierarchy_entry(
         %{name: name, path: path, label_field: label_field},
         %{table_name: current_source_table_name, fields: fields, joins: joins} =
           _source,
         opts \\ []
       ) do
    is_aggregate_values = Keyword.get(opts, :aggregate_values, false)

    %{label_field: label_field, values: values} =
      path
      |> Enum.map(fn name ->
        Enum.find(fields, &(&1.name == name))
      end)
      |> Enum.filter(fn field -> not is_nil(field) end)
      |> Enum.reduce(%{label_field: nil, values: []}, fn field, acc ->
        label_field =
          if field do
            Enum.find(fields, &(&1.name == label_field))
          else
            nil
          end

        {table_name, column_name} = get_table_and_column(field, joins)
        table_and_column = table_and_column_string(table_name, column_name)

        value =
          if is_aggregate_values do
            maybe_aggregate(
              table_and_column,
              current_source_table_name,
              table_name,
              :string
            )
          else
            table_and_column
          end

        acc
        |> Map.update(:values, [], fn existing -> [value | existing] end)
        |> Map.update(:label_field, nil, fn existing ->
          existing || label_field
        end)
      end)

    hierarchy_separator = Constants.hierarchy_separator()

    value =
      ~s(#{Enum.join(values |> Enum.reverse(), " || '#{hierarchy_separator}' || ")}::text)

    label =
      if label_field do
        {label_table_name, label_column_name} =
          get_table_and_column(label_field, joins)

        table_and_column_string(label_table_name, label_column_name)
      else
        "''"
      end

    %{name: name, value: value, label: label}
  end

  defp facet_column_wrap(key_values) do
    """
    array_to_tsvector(
      array_agg(array_remove(ARRAY[#{key_values}], NULL)) FILTER (WHERE array_remove(ARRAY[#{key_values}], NULL) <> '{}')
    ) AS tsv
    """
  end

  # Sort columns

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
       when is_list(fields) and fields != [] and is_list(sort_fields) and
              sort_fields != [] do
    all_fields = get_all_fields(search_view_description)

    # We need to generate the same sort columns for every source:
    # listed in the same order and containing the same data types.

    combined_sort_fields =
      Enum.concat(sort_fields, get_all_sort_fields(search_view_description))
      |> Enum.uniq()

    current_source_sort_field_names = sort_fields |> Enum.map(& &1.name)

    combined_sort_fields
    |> Enum.sort_by(&(&1.name |> to_string()))
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

      sort_column_name = "#{Constants.sort_field_prefix()}#{name}"

      create_sort_statement(
        %{
          transforms: sort_field.transforms,
          current_source_table_name: current_source_table_name,
          ecto_type: sort_field.ecto_type || ecto_type,
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
      transforms: transforms,
      current_source_table_name: current_source_table_name,
      ecto_type: ecto_type,
      field: field,
      joins: joins,
      sort_column_name: sort_column_name
    } = attrs

    {table_name, column_name} = get_table_and_column(field, joins)
    table_and_column = table_and_column_string(table_name, column_name)

    value =
      run_transforms(transforms, table_and_column)
      |> maybe_aggregate(
        current_source_table_name,
        table_name,
        ecto_type
      )

    "#{value} AS #{sort_column_name}"
  end

  defp create_sort_statement(
         %{
           sort_column_name: sort_column_name
         },
         _
       ) do
    "NULL AS #{sort_column_name}"
  end

  # Util functions

  defp run_transforms(transforms, value)
       when is_list(transforms) and transforms != [] do
    Enum.reduce(transforms, value, fn operation, acc ->
      operation |> String.replace("?", acc)
    end)
  end

  defp run_transforms(_transforms, value), do: value

  defp maybe_aggregate(
         value,
         current_source_table_name,
         table_name,
         ecto_type
       ) do
    needs_aggregate = current_source_table_name != table_name

    cond do
      is_tuple(ecto_type) and elem(ecto_type, 0) == :array ->
        "array_agg(DISTINCT #{value})"

      ecto_type == :string and needs_aggregate ->
        "COALESCE(string_agg(DISTINCT #{value}, ', '), '')"

      ecto_type == :boolean and needs_aggregate ->
        "every(#{value})"

      needs_aggregate ->
        "any_value(#{value})"

      true ->
        value
    end
  end

  @spec get_table_and_column(Field.t(), list(Join.t()) | nil) ::
          {atom(), atom()} | nil
  defp get_table_and_column(%Field{name: :source}, _joins),
    do: {:source, :source_name}

  defp get_table_and_column(%Field{binding: binding} = field, joins)
       when is_list(joins) and joins != [] and not is_nil(binding) do
    %{
      binding: binding,
      column: column,
      table_name: table_name
    } = field

    join = Enum.find(joins, &(&1.as == binding || &1.table == binding))

    if join do
      {join.as || join.table, column}
    else
      {table_name, field.column}
    end
  end

  # Create alias for a column in the source table
  defp get_table_and_column(
         %Field{
           table_name: table_name,
           binding: binding,
           column: column
         },
         _joins
       )
       when not is_nil(binding) and not is_nil(column),
       do: {table_name, column}

  defp get_table_and_column(
         %Field{table_name: table_name, column: column},
         _joins
       ) do
    {table_name, column}
  end

  defp get_table_and_column(_, _), do: nil

  defp table_name_with_prefix(table_name, prefix) when is_binary(prefix),
    do: "#{prefix}.#{table_name}"

  defp table_name_with_prefix(table_name, _prefix), do: table_name

  defp table_and_column_string(table_name, column_name),
    do: "#{table_name}.#{column_name}"

  @spec create_width_bucket(String.t(), list()) :: String.t()
  defp create_width_bucket(table_and_column, range_bounds) do
    range_bounds_str = Enum.map_join(range_bounds, ", ", & &1)
    "width_bucket(#{table_and_column}, ARRAY[#{range_bounds_str}])"
  end

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

  defp line_indent(level) when level == 0, do: ""
  defp line_indent(level), do: "  " <> line_indent(level - 1)
end
