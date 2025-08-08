defmodule FacetedSearch.Constants do
  @moduledoc false

  def facet_search_field_prefix, do: "facet_"
  def tsv_separator, do: "|:|"
  def scope_callback, do: :scope_by
  def option_label_callback, do: :option_label
end
