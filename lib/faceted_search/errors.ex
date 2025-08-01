defmodule FacetedSearch.Errors.InvalidOptionsError do
  @moduledoc false

  defexception [:key, :message, :value, :keys_path, :module]

  @doc false
  def from_nimble(%NimbleOptions.ValidationError{} = error, opts) do
    %__MODULE__{
      key: error.key,
      keys_path: error.keys_path,
      message: Exception.message(error),
      module: Keyword.fetch!(opts, :module),
      value: error.value
    }
  end
end

defmodule FacetedSearch.Errors.MissingCallbackError do
  @moduledoc """
  Raised when no beahviour callback was specified.
  """

  defexception [:callback, :module]

  def message(error) do
    """
    No callback defined.

    Option `scopes` was used, and that requires the behaviour callback #{error.callback} to be defined in module #{error.module}.

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

defmodule FacetedSearch.Errors.NoRepoError do
  @moduledoc """
  Raised when no Ecto repo was specified. A repo can be configured in Flop - see [Flop documentation](https://hexdocs.pm/flop).
  """

  defexception []

  def message(_) do
    """
    No repo specified.

    A repo can be configured in Flop - see Flop documentation at https://hexdocs.pm/flop
    or passed in the options parameter.
    """
  end
end

defmodule FacetedSearch.Errors.SearchViewError do
  @moduledoc """
  Raised when an error occurs when creating a materialized view.
  """

  defexception [:message]

  @impl true
  def exception(value) do
    message = """
    Search view error.

    Error creating search view:

        #{inspect(value)}

    """

    %FacetedSearch.Errors.SearchViewError{message: message}
  end
end
