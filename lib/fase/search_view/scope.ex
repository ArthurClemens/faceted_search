defmodule Fase.SearchView.Scope do
  @moduledoc """
  Definition for the [`scope_by/2` callback function](Fase.html#c:scope_by/2).
  """

  @enforce_keys [
    :key,
    :module
  ]

  defstruct key: nil,
            module: nil

  @type t() :: %__MODULE__{
          # required
          key: atom(),
          module: module()
        }

  def new(module, scope_key) do
    struct(__MODULE__, %{key: scope_key, module: module})
  end
end
