defmodule Fase.InvalidOptionsError do
  @moduledoc false

  defexception [:key, :message, :value, :keys_path, :module]

  @doc false
  def from_nimble(%NimbleOptions.ValidationError{} = error, opts) do
    %__MODULE__{
      module: Keyword.fetch!(opts, :module),
      key: error.key,
      value: error.value,
      keys_path: error.keys_path,
      message: Exception.message(error)
    }
  end

  def from_validation(errors, opts) do
    %__MODULE__{
      module: Keyword.fetch!(opts, :module),
      message: Fase.SchemaValidationData.message(errors)
    }
  end
end
