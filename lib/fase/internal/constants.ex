defmodule Fase.Internal.Constants do
  @moduledoc false

  def facet_search_field_prefix, do: "facet_"
  def sort_field_prefix, do: "sort_"

  def hierarchy_separator, do: ">"
  def facet_separator, do: "=:="

  def facet_label_callback, do: :facet_label
  def option_label_callback, do: :option_label
  def scope_callback, do: :scope_by
  def search_condition_callback, do: :search_condition
  def search_transform_callback, do: :search_transform
end
