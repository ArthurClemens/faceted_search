defmodule FacetedSearch.Config do
  @moduledoc false

  use FacetedSearch.Types, include: [:create_search_view_options]

  alias FacetedSearch.Errors.NoRepoError
  alias FacetedSearch.Errors.SearchViewError

  @search_view_prefix "fv_"
  @name_separator "_"

  @enforce_keys [
    :view_name,
    :view_name_with_prefix
  ]

  defstruct view_name: nil, view_name_with_prefix: nil, prefix: nil, current_scope: nil, repo: nil

  @type t() :: %__MODULE__{
          # required
          view_name: String.t(),
          view_name_with_prefix: String.t(),
          # optional
          prefix: String.t() | nil,
          current_scope: term() | nil,
          repo: Ecto.Repo.t() | nil
        }

  @spec new(String.t(), [create_search_view_option()]) :: t()
  def new(view_id, options \\ []) do
    if is_nil(view_id) do
      raise SearchViewError, %{error: "Missing view_id"}
    end

    current_scope = Keyword.get(options, :scope)
    prefix = Keyword.get(options, :prefix)
    repo = get_repo(options)

    {view_name, view_name_with_prefix} = create_view_name(view_id, prefix)

    %__MODULE__{
      view_name: view_name,
      view_name_with_prefix: view_name_with_prefix,
      prefix: prefix,
      current_scope: current_scope,
      repo: repo
    }
  end

  @spec create_view_name(String.t(), String.t() | nil) :: {String.t(), String.t()}
  defp create_view_name(view_id, prefix) do
    view_id |> make_safe_id() |> view_name_with_prefix(prefix)
  end

  defp view_name_with_prefix(id, prefix) do
    view_name = "#{@search_view_prefix}#{id}"
    view_name_with_prefix = if(prefix, do: "#{prefix}.#{view_name}", else: view_name)
    {view_name, view_name_with_prefix}
  end

  def get_repo(options) do
    options = Flop.get_option(:adapter_opts, options) || options

    Flop.get_option(:repo, options) ||
      raise NoRepoError
  end

  def make_safe_id(view_id) do
    view_id
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[[:punct:][:space:]]/, @name_separator)
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/\_{2,}/, @name_separator)
    |> String.trim()
    |> String.trim(@name_separator)
    |> String.downcase()
  end
end
