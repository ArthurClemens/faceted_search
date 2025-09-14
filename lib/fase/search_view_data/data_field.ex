defmodule Fase.DataField do
  @moduledoc """
  Properties of a data field that is included in the search view generation.
  """

  alias Fase.DataFieldEntry

  @enforce_keys [
    :name
  ]

  defstruct name: nil, entries: nil, cast: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          entries: list(DataFieldEntry.t()) | nil,
          cast: String.t() | nil
        }

  @spec new(atom(), Keyword.t() | nil) :: t()
  def new(name, options \\ []) do
    {cast_options, entry_options} = Keyword.split(options, [:cast])

    struct(__MODULE__, %{
      name: name,
      cast: Keyword.get(cast_options, :cast),
      entries: collect_entries(entry_options)
    })
  end

  defp collect_entries(entry_options) when entry_options != [] do
    entry_options
    |> Enum.map(fn
      {name, options} when is_list(options) ->
        field_name = if Keyword.get(options, :binding), do: nil, else: name

        struct(
          DataFieldEntry,
          options
          |> Keyword.put(:name, name)
          |> Keyword.put(:field_name, field_name)
        )

      name ->
        struct(
          DataFieldEntry,
          %{name: name, field_name: name}
        )
    end)
  end

  defp collect_entries(_), do: nil
end

defmodule Fase.DataFieldEntry do
  @moduledoc """
  Properties of a data field entry that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil, binding: nil, column: nil, field_name: nil, cast: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          binding: atom() | nil,
          column: atom() | nil,
          field_name: atom() | nil,
          cast: String.t() | nil
        }
end
