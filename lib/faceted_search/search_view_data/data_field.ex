defmodule FacetedSearch.DataField do
  @moduledoc """
  Properties of a data field that is included in the search view generation.
  """

  alias FacetedSearch.DataFieldEntry

  @enforce_keys [
    :name
  ]

  defstruct name: nil, entries: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          entries: list(DataFieldEntry.t()) | nil
        }

  @spec new(atom(), Keyword.t() | nil) :: t()
  def new(name, field_options \\ []) do
    struct(__MODULE__, %{
      name: name,
      entries: Keyword.get(field_options, :entries) |> collect_entries()
    })
  end

  defp collect_entries(entry_options) when is_list(entry_options) do
    entry_options
    |> Enum.map(fn {name, options} ->
      struct(
        DataFieldEntry,
        options
        |> Keyword.put(:name, name)
      )
    end)
  end

  defp collect_entries(_), do: nil
end

defmodule FacetedSearch.DataFieldEntry do
  @moduledoc """
  Properties of a data field entry that is included in the search view generation.
  """

  @enforce_keys [
    :name,
    :binding,
    :field
  ]

  defstruct name: nil, binding: nil, field: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          binding: atom(),
          field: atom()
        }
end
