defmodule FacetedSearch do
  @moduledoc """
  FacetedSearch integrates faceting into your application with [Flop](https://hexdocs.pm/flop) as the underlying search library.

  For an overview of the library, visit the [README](README.md).
  """

  use FacetedSearch.Types,
    include: [:schema_options, :create_search_view_options, :flop_adapter_options]

  alias FacetedSearch.Facet
  alias FacetedSearch.Facets
  alias FacetedSearch.FlopSchema
  alias FacetedSearch.NimbleSchema
  alias FacetedSearch.SearchView
  alias FacetedSearch.SearchViewDescription

  @doc """
  Configures FacetedSearch to create a search view from one or more existing database tables and columns.

  ## Example

      use FacetedSearch, [options]

  ## Supported options

  #{NimbleOptions.docs(NimbleSchema.option_schema())}

  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      options =
        NimbleSchema.validate!(
          Keyword.put(opts, :module, __MODULE__),
          __MODULE__
        )

      custom_fields_option =
        FlopSchema.create_custom_fields_option(options)

      filterable_fields_option =
        FlopSchema.create_filterable_fields_option(custom_fields_option)

      use Ecto.Schema

      use FacetedSearch.Types,
        include: [:schema_options, :create_search_view_options, :flop_adapter_options]

      @primary_key false

      @derive {
        Flop.Schema,
        filterable: filterable_fields_option,
        adapter_opts: [
          custom_fields: custom_fields_option
        ],
        sortable: [],
        default_order: %{
          order_by: [],
          order_directions: []
        }
      }

      schema "faceted_search_document" do
        field(:id, :string)
        field(:table_name, :string)
        field(:data, :map)
        field(:text, :string)
      end

      @type t() :: %__MODULE__{
              # required
              id: String.t(),
              table_name: String.t(),
              text: String.t(),
              data: map()
            }

      @doc """
      Returns the provided options.
      """
      @spec options() :: schema_options()
      def options, do: unquote(Macro.escape(options))

      @spec ecto_schema(String.t()) :: Ecto.Queryable.t()
      def ecto_schema(view_id), do: {SearchView.search_view_name(view_id), __MODULE__}

      @spec search_view_description() :: SearchViewDescription.t()
      def search_view_description, do: SearchView.create_search_view_description(options())

      @spec create_search_view(String.t(), [create_search_view_option()]) ::
              :ok | {:error, term()}
      def create_search_view(view_id, opts \\ []),
        do: SearchView.create_search_view(options(), view_id, opts)

      @spec create_search_view_if_not_exists(String.t(), [create_search_view_option()]) ::
              :ok | {:error, term()}
      def create_search_view_if_not_exists(view_id, opts \\ []),
        do: SearchView.create_search_view_if_not_exists(options(), view_id, opts)

      @spec refresh_search_view(String.t(), [create_search_view_option()]) ::
              :ok | {:error, term()}
      def refresh_search_view(view_id, opts \\ []),
        do: SearchView.refresh_search_view(view_id, opts)

      @spec drop_search_view(String.t(), [create_search_view_option()]) ::
              :ok | {:error, term()}
      def drop_search_view(view_id, opts \\ []),
        do: SearchView.drop_search_view(view_id, opts)

      @spec search_view_name(String.t()) :: String.t()
      def search_view_name(view_id), do: SearchView.search_view_name(view_id)

      @spec search(Ecto.Queryable.t(), map() | nil, [flop_adapter_option()]) ::
              {:ok, list(Facet.t())}
              | {:error, Flop.Meta.t()}
              | {:error, Exception.t()}
      def search(ecto_schema, search_params \\ %{}, opts \\ []) do
        Facets.search(ecto_schema, search_params, opts)
      end
    end
  end

  @typep scope_key :: atom()
  @typep scope :: term()

  @doc """
  Configures one or more scopes when creating the search view.
  Use together with `collection`: option `scopes` lists one or more scope keys.
  These are used to selectivelt call the `scope_by/2` callback functions.
  Each returned map is used to render a `WHERE` clause in the search view creation.

  See also: `create_search_view/3`.

  ## Examples

  If the schema module contains:

      defmodule KitchenJournalSchemas.FacetSchema do

          use FacetedSearch,
            collections: [
              media: [
                scopes: [:current_user, :publication_year],
                ...

  Then 2 `scopy_by/2` callback functions with corresponding keys will define the scope rules. For example:

      defmodule KitchenJournalSchemas.FacetSchema do

          @behaviour FacetedSearch
          def scope_by(:current_user, scope) do
            %{
              field: :user_id,
              comparison: "=",
              value: scope.user.id
            }
          end

          def scope_by(:publication_year, scope) do
            %{
              field: :publication_year,
              comparison: ">",
              value: scope.publication_year
            }
          end

          use FacetedSearch,
            ...
  """
  @callback scope_by(scope_key, scope | nil) :: %{
              table: atom() | nil,
              field: atom(),
              comparison: String.t(),
              value: term()
            }

  @optional_callbacks scope_by: 2

  @doc """
  Creates a search view that collects data for searching.

  Options:
  - `scope` (optional) - The scope to be passed to the module function provided with option `scope_by` - see: [Supported options](#__using__/1-supported-options) under "collections".
  - `repo` (only if not already set in the Flop config) - The `Ecto.Repo` module.

  ## Examples

      iex> FacetedSearch.create_search_view(MyApp.FacetSchema, "books")
      :ok

      iex> FacetedSearch.create_search_view(MyApp.FacetSchema, "books",
      ...>   scope: %{current_user: current_user})
      :ok


  """
  @spec create_search_view(module(), String.t(), [create_search_view_option()]) ::
          :ok | {:error, term()}
  def create_search_view(module, view_id, opts \\ []),
    do: module.create_search_view(view_id, opts)

  @doc """
  Creates the search view if it does not exist.
  """
  @spec create_search_view_if_not_exists(module(), String.t(), [create_search_view_option()]) ::
          :ok | {:error, term()}
  def create_search_view_if_not_exists(module, view_id, opts \\ []),
    do: module.create_search_view_if_not_exists(view_id, opts)

  @doc """
  Refreshes the search view.

  ## Examples

      iex> FacetedSearch.refresh_search_view(MyApp.FacetSchema, "books")
      :ok

  """
  @spec refresh_search_view(module(), String.t(), [create_search_view_option()]) ::
          :ok | {:error, term()}
  def refresh_search_view(module, view_id, opts \\ []),
    do: module.refresh_search_view(view_id, opts)

  @doc """
  Drops the search view.

  ## Examples

      iex> FacetedSearch.refresh_search_view(MyApp.FacetSchema, "books")
      :ok

  """
  @spec drop_search_view(module(), String.t(), [create_search_view_option()]) ::
          :ok | {:error, term()}
  def drop_search_view(module, view_id, opts \\ []),
    do: module.drop_search_view(view_id, opts)

  @doc """
  Returns the provided options. Useful for debugging issues.

  ## Examples

      iex> FacetedSearch.options(MyApp.FacetSchema)
      [name: "books", ...]

  """
  @spec options(module()) :: schema_options()
  def options(module),
    do: module.options()

  @doc """
  Returns the generated view struct used to build the search view. Useful for debugging issues.

  ## Examples

      iex> FacetedSearch.search_view_description(MyApp.FacetSchema)
      %FacetedSearch.SearchViewDescription{}

  """
  @spec search_view_description(module()) :: SearchViewDescription.t()
  def search_view_description(module),
    do: module.search_view_description()

  @doc """
  The normalized Postgres view name generated from `view_id`.
  The view name is prefixed with `"fv_"`.

  ## Examples

      iex> FacetedSearch.search_view_name(MyApp.FacetSchema, "books")
      "fv_books"

  """
  @spec search_view_name(module(), String.t()) :: String.t()
  def search_view_name(module, view_id),
    do: module.search_view_name(view_id)

  @doc """
  Returns the Ecto schema for the search view.

  ## Examples

      iex> FacetedSearch.ecto_schema(MyApp.FacetSchema, "books")
      {"fv_books", MyApp.FacetSchema}

      iex> ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "books")
      ...> from(ecto_schema)
      ...> |> Flop.validate_and_run(search_params, for: MyApp.FacetSchema)
  """
  @spec ecto_schema(module(), String.t()) :: Ecto.Queryable.t()
  def ecto_schema(module, view_id),
    do: module.ecto_schema(view_id)

  @doc """
  Performs a Flop search with search params and returns a list of matching facets.

  ## Examples

      view_id = user.id
      ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, view_id)

      with {:ok, results} <-
             from(ecto_schema) |> Flop.validate_and_run(params, for: MyApp.FacetSchema),
           {:ok, facets} <- FacetedSearch.search(ecto_schema, params) do
        {:ok, results, facets}
      else
        error -> error
      end
  """
  @spec search(Ecto.Queryable.t(), map() | nil, [flop_adapter_option()]) ::
          {:ok, list(Facet.t())}
          | {:error, Flop.Meta.t()}
          | {:error, Exception.t()}
  def search(ecto_schema, search_params \\ %{}, opts \\ []) do
    {_view_name, module} = ecto_schema
    module.search(ecto_schema, search_params, opts)
  end
end
