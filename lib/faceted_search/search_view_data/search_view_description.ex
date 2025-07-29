defmodule FacetedSearch.SearchViewDescription do
  @moduledoc """
  The search view configuration of the processed schema.
  """

  use FacetedSearch.Types, include: [:schema_options]

  alias FacetedSearch.Source

  @enforce_keys [
    :sources
  ]

  defstruct sources: nil

  @type t() :: %__MODULE__{
          # required
          sources: list(Source.t())
        }

  @spec new(schema_options()) :: t()
  def new(options) do
    module = Keyword.get(options, :module)

    struct(__MODULE__, %{
      sources:
        options
        |> Keyword.get(:sources)
        |> Enum.map(&Source.new(&1, module))
    })
  end
end
