defmodule Fase.Constants do
  @moduledoc false

  def facet_search_field_prefix, do: "facet_"
  def sort_field_prefix, do: "sort_"
  def tsv_separator, do: "=:="
  def hierarchy_separator, do: ">"
  def scope_callback, do: :scope_by
  def option_label_callback, do: :option_label

  @ecto_to_postgres_types %{
    array_integer: "integer[]",
    array_string: "text[]",
    array_uuid: "uuid[]",
    bigint: "bigint",
    binary: "bytea",
    boolean: "boolean",
    date: "date",
    decimal: "numeric",
    float: "double precision",
    id: "bigint",
    integer: "integer",
    map: "jsonb",
    naive_datetime_usec: "timestamp(6) without time zone",
    naive_datetime: "timestamp",
    string: "varchar",
    text: "text",
    time_usec: "time(6)",
    time: "time",
    utc_datetime_usec: "timestamp(6) without time zone",
    utc_datetime: "timestamp",
    uuid: "uuid"
  }
  def ecto_type_to_postgres(ecto_type), do: @ecto_to_postgres_types[ecto_type]
end
