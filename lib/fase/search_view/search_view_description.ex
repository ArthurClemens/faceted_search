defmodule Fase.SearchView.SearchViewDescription do
  @moduledoc """
  The search view configuration of the processed schema.
  """

  use Fase.Internal.Types, include: [:schema_options]

  alias Fase.SearchView.Source

  @enforce_keys [
    :sources
  ]

  defstruct sources: nil, id: nil

  @type t() :: %__MODULE__{
          # required
          sources: list(Source.t()),
          # optional
          id: map() | nil
        }

  @spec new(schema_options()) :: t()
  def new(options) do
    module = Keyword.get(options, :module)

    id_config =
      if Keyword.has_key?(options, :id) do
        Keyword.get(options, :id, []) |> Enum.into(%{})
      else
        nil
      end

    struct(__MODULE__, %{
      id: id_config,
      sources:
        options
        |> Keyword.get(:sources)
        |> Enum.map(&Source.new(&1, module))
    })
  end
end
