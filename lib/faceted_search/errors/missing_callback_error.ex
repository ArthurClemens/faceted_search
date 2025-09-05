defmodule FacetedSearch.MissingCallbackError do
  @moduledoc """
  Raised when no behaviour callback was specified.
  """

  defexception [:callback, :module]

  def message(error) do
    """

        No callback defined.

        Option "scopes" was used, and that requires the behaviour callback #{error.callback} to be defined in module #{error.module}.

        Example:

            For schema with option:

                scopes: [:current_user],
                ...

            Add a function `scope_by/2` that accepts the same key and a scope parameter to read from:

                def scope_by(:current_user, current_user) do
                  %{
                    field: "user_id",
                    comparison: "=",
                    value: current_user.id
                  }
                end
    """
  end
end
