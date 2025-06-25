defmodule FacetedSearch.SearchViewDescription do
  @moduledoc """
  Data struct used for building the search view.
  """

  use FacetedSearch.Types, include: [:schema_options]

  alias FacetedSearch.Collection

  @enforce_keys [
    :collections
  ]

  defstruct collections: nil

  @type t() :: %__MODULE__{
          # required
          collections: list(Collection.t())
        }

  @spec new(schema_options()) :: t()
  def new(options) do
    module = Keyword.get(options, :module)

    struct(__MODULE__, %{
      collections:
        options
        |> Keyword.get(:collections)
        |> Enum.map(&Collection.new(&1, module))
    })
  end
end
