defmodule FacetedSearch.FacetConfig do
  @moduledoc """
  Contains type information for a facet.
  """

  use FacetedSearch.Types,
    include: [:range_types]

  alias FacetedSearch.FacetConfig
  alias FacetedSearch.SearchViewDescription

  @enforce_keys [
    :ecto_type
  ]

  defstruct ecto_type: nil, range_bounds: nil, range_buckets: nil

  @type t() :: %__MODULE__{
          # required
          ecto_type: Ecto.Type.t(),
          # optional
          range_bounds: list(range_bound()) | nil,
          range_buckets: list(range_bucket()) | nil
        }

  @doc """
  Creates facet configs from a SearchViewDescription.
  """
  @spec facet_configs(SearchViewDescription.t()) :: %{atom() => FacetConfig.t()}
  def facet_configs(search_view_description) do
    sources = search_view_description.sources

    ecto_types_by_field =
      get_in(sources, [Access.all(), Access.key(:fields)])
      |> List.flatten()
      |> Enum.filter(& &1)
      |> Enum.reduce(%{}, fn data_field, acc ->
        Map.put(acc, data_field.name, data_field.ecto_type)
      end)

    get_in(sources, [Access.all(), Access.key(:facet_fields)])
    |> List.flatten()
    |> Enum.filter(& &1)
    |> Enum.reduce(%{}, fn facet_field, acc ->
      Map.put(acc, facet_field.name, %FacetConfig{
        ecto_type: ecto_types_by_field[facet_field.name],
        range_bounds: facet_field.range_bounds,
        range_buckets: facet_field.range_buckets
      })
    end)
  end
end
