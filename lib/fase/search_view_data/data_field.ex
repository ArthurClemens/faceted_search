defmodule Fase.DataField do
  @moduledoc """
  Properties of a data field that is included in the search view generation.
  """

  alias Fase.CustomDataFieldEntry

  @enforce_keys [
    :name
  ]

  defstruct name: nil, entries: nil, operations: nil, ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          entries: list(CustomDataFieldEntry.t()) | nil,
          operations: list(String.t()) | nil,
          ecto_type: atom() | nil
        }

  @spec new(atom(), Keyword.t() | nil) :: t()
  def new(name, options \\ []) do
    {operation_options, entry_options} =
      Keyword.split(options, [:operations, :ecto_type])

    struct(__MODULE__, %{
      name: name,
      operations: Keyword.get(operation_options, :operations),
      ecto_type: Keyword.get(operation_options, :ecto_type),
      entries: collect_entries(entry_options)
    })
  end

  defp collect_entries(entry_options) when entry_options != [] do
    entry_options
    |> Enum.map(fn
      {name, options} when is_list(options) ->
        field_name = if Keyword.get(options, :binding), do: nil, else: name

        struct(
          CustomDataFieldEntry,
          options
          |> Keyword.put(:name, name)
          |> Keyword.put(:field_name, field_name)
        )

      name ->
        struct(
          CustomDataFieldEntry,
          %{name: name, field_name: name}
        )
    end)
  end

  defp collect_entries(_), do: nil
end

defmodule Fase.CustomDataFieldEntry do
  @moduledoc """
  Properties of a data field entry that is included in the search view generation.
  """

  @enforce_keys [
    :name
  ]

  defstruct name: nil,
            binding: nil,
            column: nil,
            field_name: nil,
            operations: nil,
            ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          binding: atom() | nil,
          column: atom() | nil,
          field_name: atom() | nil,
          operations: list(String.t()) | nil,
          ecto_type: atom() | nil
        }
end
