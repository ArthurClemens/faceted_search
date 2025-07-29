defmodule FacetedSearch.Join do
  @moduledoc """
  Properties of a joined field that is included in the search view generation.
  """

  @enforce_keys [
    :table,
    :on
  ]

  defstruct table: nil, on: nil, as: nil, prefix: nil

  @type t() :: %__MODULE__{
          # required
          on: String.t(),
          table: atom(),

          # optional
          as: String.t() | nil,
          prefix: String.t() | nil
        }

  @spec new(atom(), Keyword.t()) :: t()
  def new(name, options) do
    {table, as} =
      if Keyword.has_key?(options, :table) do
        {Keyword.get(options, :table), name}
      else
        {name, nil}
      end

    struct(
      __MODULE__,
      options
      |> Keyword.put(:table, table)
      |> Keyword.put(:as, as)
    )
  end
end
