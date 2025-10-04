defmodule Fase.Internal.FacetConfig do
  @moduledoc false

  use Fase.Internal.Types,
    include: [:range_types]

  alias Fase.Internal.Constants
  alias Fase.Internal.FacetConfig
  alias Fase.SearchView.SearchViewDescription

  @enforce_keys [
    :name,
    :field,
    :field_reference,
    :ecto_type,
    :hide_when_selected
  ]

  defstruct name: nil,
            field: nil,
            field_reference: nil,
            ecto_type: nil,
            hide_when_selected: false,
            range_bounds: nil,
            range_buckets: nil,
            hierarchy: nil,
            parent: nil

  @type t() :: %__MODULE__{
          # required
          name: String.t(),
          field: atom(),
          field_reference: atom(),
          ecto_type: Ecto.Type.t(),
          hide_when_selected: boolean(),
          # optional
          range_bounds: list(range_bound()) | nil,
          range_buckets: list(range_bucket()) | nil,
          hierarchy: boolean() | nil,
          parent: atom() | nil
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

      ecto_type =
        cond do
          not is_nil(facet_field.hierarchy) -> :string
          not is_nil(facet_field.ecto_type) -> facet_field.ecto_type
          true -> ecto_types_by_field[facet_field.name]
        end

      Map.put(acc, facet_field.name, %FacetConfig{
        name: to_string(facet_field.name),
        field: facet_field.name,
        field_reference: field_reference,
        ecto_type: ecto_type,
        range_bounds: facet_field.range_bounds,
        range_buckets: facet_field.range_buckets,
        hierarchy: facet_field.hierarchy,
        parent: facet_field.parent,
        hide_when_selected: facet_field.hide_when_selected
      })
    end)
  end
end
