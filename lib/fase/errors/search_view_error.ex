defmodule Fase.SearchViewError do
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

    %Fase.SearchViewError{message: message}
  end
end
