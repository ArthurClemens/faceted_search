defmodule FacetedSearch.FacetConfig do
  @moduledoc """
  Contains type information for a facet.
  """

  use FacetedSearch.Types,
    include: [:range_types]

  alias FacetedSearch.Constants
  alias FacetedSearch.FacetConfig
  alias FacetedSearch.SearchViewDescription

  @enforce_keys [
    :field_reference,
    :ecto_type
  ]

  defstruct field_reference: nil,
            ecto_type: nil,
            range_bounds: nil,
            range_buckets: nil

  @type t() :: %__MODULE__{
          # required
          field_reference: atom(),
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
      prefix = Constants.facet_search_field_prefix()

      field_reference =
        if facet_field.range_bounds,
          do: "#{prefix}#{facet_field.name}" |> String.to_existing_atom(),
          else: facet_field.name

      Map.put(acc, facet_field.name, %FacetConfig{
        field_reference: field_reference,
        ecto_type: ecto_types_by_field[facet_field.name],
        range_bounds: facet_field.range_bounds,
        range_buckets: facet_field.range_buckets
      })
    end)
  end
end
