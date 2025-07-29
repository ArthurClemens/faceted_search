defmodule FacetedSearch.Filter do
  @moduledoc false

  # Filters for custom fields
  # Adds support for searching the `data` JSON field in the document view table.

  import Ecto.Query, warn: false

  require Logger

  def filter(query, %Flop.Filter{field: field, value: value, op: op}, opts) do
    ecto_type = Keyword.get(opts, :ecto_type)
    source_is_array = Keyword.get(opts, :source_is_array, false)

    value_type =
      case ecto_type do
        {:array, type} -> type
        type -> type
      end

    cast_value = Ecto.Type.cast(ecto_type, value)

    case cast_value do
      {:ok, query_value} ->
        source_is_array_value = is_list(value)

        {name, is_facet_search} = extract_name_attributes(field)
        expr = dynamic_expr(name, ecto_type, source_is_array, is_facet_search)

        conditions =
          cond do
            is_facet_search ->
              get_facet_conditions(op, value_type, expr, query_value, source_is_array)

            source_is_array_value ->
              get_array_conditions(op, value_type, expr, query_value)

            true ->
              get_conditions(op, expr, query_value)
          end

        where(query, ^conditions)

      :error ->
        Logger.error("Error casting value #{value} for field '#{field}'")
        query
    end
  end

  def facet_search_field_prefix, do: "facet_"

  @spec extract_name_attributes(atom()) :: {String.t(), boolean()}
  defp extract_name_attributes(field) do
    name_str = to_string(field)
    is_facet_search = String.starts_with?(name_str, facet_search_field_prefix())
    name = String.trim_leading(name_str, facet_search_field_prefix())
    {name, is_facet_search}
  end

  defp get_conditions(:==, expr, query_value), do: dynamic([r], ^expr == ^query_value)
  defp get_conditions(:!=, expr, query_value), do: dynamic([r], ^expr != ^query_value)
  defp get_conditions(:>, expr, query_value), do: dynamic([r], ^expr > ^query_value)
  defp get_conditions(:<, expr, query_value), do: dynamic([r], ^expr < ^query_value)
  defp get_conditions(:>=, expr, query_value), do: dynamic([r], ^expr >= ^query_value)
  defp get_conditions(:<=, expr, query_value), do: dynamic([r], ^expr <= ^query_value)

  defp get_conditions(op, expr, query_value)
       when op in [
              :like,
              :ilike,
              :like_and,
              :ilike_and,
              :like_or,
              :ilike_or,
              :not_like,
              :not_ilike
            ],
       do: collect_string_conditions(op, expr, query_value)

  defp get_conditions(op, expr, query_value) do
    Logger.error("Operator #{op} for query value '#{query_value}' is not supported")
    expr
  end

  defp get_array_conditions(:==, :string, expr, query_value) do
    dynamic(
      [r],
      fragment("? \\?& STRING_TO_ARRAY(?, ',')", ^expr, ^(query_value |> Enum.join(",")))
    )
  end

  defp get_facet_conditions(:==, :string, expr, query_value, source_is_array)
       when source_is_array do
    dynamic(
      [r],
      fragment("? \\?| STRING_TO_ARRAY(?, ',')", ^expr, ^(query_value |> Enum.join(",")))
    )
  end

  defp get_facet_conditions(:==, :string, expr, query_value, _source_is_array) do
    dynamic(
      [r],
      fragment("? <@ STRING_TO_ARRAY(?, ',')::text[]", ^expr, ^(query_value |> Enum.join(",")))
    )
  end

  defp get_facet_conditions(:==, :boolean, expr, query_value, _source_is_array) do
    dynamic(
      [r],
      fragment("? <@ STRING_TO_ARRAY(?, ',')::boolean[]", ^expr, ^(query_value |> Enum.join(",")))
    )
  end

  defp get_facet_conditions(:==, :integer, expr, query_value, _source_is_array) do
    dynamic(
      [r],
      fragment("? <@ STRING_TO_ARRAY(?, ',')::int[]", ^expr, ^(query_value |> Enum.join(",")))
    )
  end

  defp get_facet_conditions(op, _value_type, expr, query_value, _source_is_array) do
    Logger.error("Operator #{op} for query value '#{query_value}' is not supported")
    expr
  end

  def dynamic_expr(name, :integer, _source_is_array, _is_facet_search) do
    dynamic(
      [r],
      fragment(
        "CAST((?->>?) AS int)",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, :boolean, _source_is_array, _is_facet_search) do
    dynamic(
      [r],
      fragment(
        "CAST((?->>?) AS boolean)",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, {:array, _}, source_is_array, _is_facet_search) when source_is_array do
    dynamic(
      [r],
      fragment(
        "CAST((?->>?) AS jsonb)",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, {:array, :integer}, _source_is_array, is_facet_search)
      when is_facet_search do
    dynamic(
      [r],
      fragment(
        "ARRAY[CAST((?->>?) AS int)]",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, {:array, :boolean}, _source_is_array, is_facet_search)
      when is_facet_search do
    dynamic(
      [r],
      fragment(
        "ARRAY[CAST((?->>?) AS boolean)]",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, {:array, :string}, _source_is_array, is_facet_search)
      when is_facet_search do
    dynamic(
      [r],
      fragment(
        "ARRAY[(?->>?)]",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, {:array, _}, _source_is_array, _is_facet_search) do
    dynamic(
      [r],
      fragment(
        "CAST((?->>?) AS jsonb)",
        field(r, :data),
        ^name
      )
    )
  end

  def dynamic_expr(name, _ecto_type, _source_is_array, _is_facet_search) do
    dynamic(
      [r],
      fragment(
        "?->>?",
        field(r, :data),
        ^name
      )
    )
  end

  defp collect_string_conditions(op, expr, query_value) do
    op_combinator = combinator(op)
    op_operator_fn = operator_query_fn(op)

    query_value
    |> Flop.Misc.split_search_text()
    |> Enum.map(&op_operator_fn.(&1, expr))
    |> dynamic_reducer(op_combinator)
  end

  defp combinator(:like_or), do: :or
  defp combinator(:ilike_or), do: :or
  defp combinator(_), do: :and

  defp operator_query_fn(op) when op in [:like, :like_or, :like_and], do: &like_operator_query/2

  defp operator_query_fn(op) when op in [:ilike, :ilike_or, :ilike_and],
    do: &ilike_operator_query/2

  defp operator_query_fn(op) when op in [:not_like], do: &not_like_operator_query/2
  defp operator_query_fn(op) when op in [:not_ilike], do: &not_ilike_operator_query/2

  defp operator_query_fn(op) do
    Logger.error("Operator query #{op} is not supported")
  end

  defp like_operator_query(term, expr), do: dynamic([r], fragment("? LIKE ?", ^expr, ^term))
  defp ilike_operator_query(term, expr), do: dynamic([r], fragment("? ILIKE ?", ^expr, ^term))

  defp not_like_operator_query(term, expr),
    do: dynamic([r], fragment("? NOT LIKE ?", ^expr, ^term))

  defp not_ilike_operator_query(term, expr),
    do: dynamic([r], fragment("? NOT ILIKE ?", ^expr, ^term))

  defp dynamic_reducer(dynamic, :and) do
    Enum.reduce(dynamic, fn dynamic, acc ->
      dynamic([r], ^acc and ^dynamic)
    end)
  end

  defp dynamic_reducer(dynamic, :or) do
    Enum.reduce(dynamic, fn dynamic, acc ->
      dynamic([r], ^acc or ^dynamic)
    end)
  end
end
