defmodule FacetedSearch.FacetField do
  @moduledoc """
  Properties of a facet field that is included in the search view generation.
  """

  use FacetedSearch.Types,
    include: [:range_types]

  @enforce_keys [
    :name
  ]

  defstruct name: nil, label_field: nil, range_bounds: nil, range_buckets: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          label_field: atom() | nil,
          range_bounds: list(range_bound()) | nil,
          range_buckets: list(range_bucket()) | nil
        }

  def new(field_options) do
    {name, field_opts} =
      case field_options do
        {name, opts} -> {name, opts}
        name -> {name, []}
      end

    label_field = Keyword.get(field_opts, :label)

    range_bounds =
      if Keyword.has_key?(field_opts, :range_bounds) do
        Keyword.get(field_opts, :range_bounds) |> Enum.sort()
      end

    range_buckets = create_range_buckets(range_bounds)

    struct(
      __MODULE__,
      %{
        name: name,
        label_field: label_field,
        range_bounds: range_bounds,
        range_buckets: range_buckets
      }
    )
  end

  @spec create_range_buckets(list(range_bound())) :: list(range_bucket())
  defp create_range_buckets(range_bounds) when is_list(range_bounds) and range_bounds != [] do
    lower = List.first(range_bounds) - 1
    upper = List.last(range_bounds) + 1

    [[:lower], range_bounds, range_bounds, [:upper]]
    |> List.flatten()
    |> Enum.sort_by(fn
      :lower -> lower
      :upper -> upper
      value -> value
    end)
    |> Enum.chunk_every(2)
    |> Enum.with_index()
  end

  defp create_range_buckets(_range_bounds), do: nil
end
