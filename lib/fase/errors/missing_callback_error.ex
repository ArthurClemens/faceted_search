defmodule Fase.Errors.MissingCallbackError do
  @moduledoc """
  Raised when no behaviour callback was specified.
  """

  defexception [:callback, :module]

  def message(error) do
    """

        No callback defined.

        Option "scope" was used, and that requires the behaviour callback #{error.callback} to be defined in module #{error.module}.

        Make sure to place the callback below `use Fase`.

        Example:

            Add a function `scope_by/2` that accepts the same key and a scope parameter to read from:

                def scope_by(:current_user, current_user) do
                  %{
                    field: "user_id",
                    comparison: "=",
                    value: current_user.id
                  }
                end

                use Fase,
                  sources: [
                    scope: [...],
                  ]
    """
  end
end
