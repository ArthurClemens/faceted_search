defmodule FacetedSearch.FacetConfig do
  @moduledoc """
  Contains type information for a facet.
  """

  alias FacetedSearch.FacetConfig
  alias FacetedSearch.SearchViewDescription

  @enforce_keys [
    :ecto_type
  ]

  defstruct ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          ecto_type: Ecto.Type.t()
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
      Map.put(acc, facet_field, %FacetConfig{
        ecto_type: ecto_types_by_field[facet_field]
      })
    end)
  end
end
