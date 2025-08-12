defmodule FacetedSearch.FacetField do
  @moduledoc """
  Properties of a facet field that is included in the search view generation.
  """

  use FacetedSearch.Types,
    include: [:range_types]

  @enforce_keys [
    :name
  ]

  defstruct name: nil,
            label_field: nil,
            range_bounds: nil,
            range_buckets: nil,
            hierarchy: nil,
            path: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          label_field: atom() | nil,
          range_bounds: list(range_bound()) | nil,
          range_buckets: list(range_bucket()) | nil,
          hierarchy: boolean() | nil,
          path: list(atom()) | nil
        }

  def new(field_options) do
    {name, field_opts} =
      case field_options do
        {name, opts} -> {name, opts}
        name -> {name, []}
      end

    {range_bounds, range_buckets} =
      cond do
        Keyword.has_key?(field_opts, :number_range_bounds) ->
          range_bounds = Keyword.get(field_opts, :number_range_bounds) |> Enum.sort()
          range_buckets = create_range_buckets(range_bounds)
          {range_bounds, range_buckets}

        Keyword.has_key?(field_opts, :date_range_bounds) ->
          range_bounds = Keyword.get(field_opts, :date_range_bounds)
          range_buckets = create_range_buckets(range_bounds)
          {Enum.map(range_bounds, &maybe_type_range_bound_entry/1), range_buckets}

        true ->
          {nil, nil}
      end

    struct(
      __MODULE__,
      %{
        name: name,
        label_field: Keyword.get(field_opts, :label),
        range_bounds: range_bounds,
        range_buckets: range_buckets,
        hierarchy: Keyword.get(field_opts, :hierarchy),
        path: Keyword.get(field_opts, :path)
      }
    )
  end

  @spec create_range_buckets(list(range_bound())) :: list(range_bucket())
  defp create_range_buckets(range_bounds) when is_list(range_bounds) and range_bounds != [] do
    Enum.zip([:lower] ++ range_bounds, range_bounds ++ [:upper])
    |> Enum.map(fn {a, b} -> [a, b] end)
    |> Enum.with_index()
  end

  defp create_range_buckets(_range_bounds), do: nil

  defp maybe_type_range_bound_entry(entry) when is_binary(entry) do
    if date_string?(entry) do
      "'#{entry}'::date"
    else
      entry
    end
  end

  defp maybe_type_range_bound_entry(entry), do: entry

  defp date_string?(entry) do
    entry
    |> String.slice(0, 10)
    |> Date.from_iso8601()
    |> case do
      {:ok, _} -> true
      _ -> false
    end
  end
end
