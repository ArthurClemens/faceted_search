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
  def new(name, entry_options \\ []) do
    struct(__MODULE__, %{
      name: name,
      entries: collect_entries(entry_options)
    })
  end

  defp collect_entries(entry_options) when entry_options != [] do
    entry_options
    |> Enum.map(fn
      {name, options} when is_list(options) ->
        field_ref = if Keyword.get(options, :binding), do: nil, else: name

        struct(
          DataFieldEntry,
          options
          |> Keyword.put(:name, name)
          |> Keyword.put(:field_ref, field_ref)
        )

      name ->
        struct(
          DataFieldEntry,
          %{name: name, field_ref: name}
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
    :name
  ]

  defstruct name: nil, binding: nil, field: nil, field_ref: nil, cast: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          binding: atom() | nil,
          field: atom() | nil,
          field_ref: atom() | nil,
          cast: atom() | nil
        }
end
