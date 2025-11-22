defmodule Fase.SearchView.DataField do
  @moduledoc """
  Properties of a data field that is included in the search view generation.
  """

  alias Fase.SearchView.CustomDataFieldEntry

  @enforce_keys [
    :name
  ]

  defstruct name: nil, entries: nil, transforms: nil, ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          entries: list(CustomDataFieldEntry.t()) | nil,
          transforms: list(String.t()) | nil,
          ecto_type: atom() | nil
        }

  @spec new(atom(), map(), Keyword.t() | nil) :: t()
  def new(name, field_ecto_types, options \\ []) do
    {operation_options, entry_options} =
      if Keyword.has_key?(options, :transforms) or
           Keyword.has_key?(options, :ecto_type) do
        Keyword.split(options, [:transforms, :ecto_type])
      else
        {[], options}
      end

    struct(__MODULE__, %{
      name: name,
      transforms: Keyword.get(operation_options, :transforms),
      ecto_type: field_ecto_types[name],
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

defmodule Fase.SearchView.CustomDataFieldEntry do
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
            transforms: nil,
            ecto_type: nil

  @type t() :: %__MODULE__{
          # required
          name: atom(),
          # optional
          binding: atom() | nil,
          column: atom() | nil,
          field_name: atom() | nil,
          transforms: list(String.t()) | nil,
          ecto_type: atom() | nil
        }
end
