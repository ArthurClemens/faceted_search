defmodule FacetedSearch.NoRepoError do
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
