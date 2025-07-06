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
  Defines the database schema for the search view. Pass the schema configuration via the options.

  Create a module to contain the schema, for example `MyApp.FacetSchema`:

  ```
  defmodule MyApp.FacetSchema do

    use FacetedSearch, [
      # options
    ]

  end
  ```

  ## Example

  Minimal schema example:

  ```
  use FacetedSearch,
    sources: [
      books: [
        fields: [
          title: [
            ecto_type: :string
          ],
          publication_year: [
            ecto_type: :integer
          ]
        ],
        data_fields: [
          :title,
          :publication_year
        ],
        text_fields: [
          :title,
        ],
        facet_fields: [
          :publication_year
        ]
      ]
    ]
  ```


  ## Schema options

  ### sources {: .underline}

  Settings per source. The source key refers to the name of a source table in your repo.

  - Type: `list(Keyword.t())`
  - Path: `sources` (schema root)
  - Required

  #### Example

  ```
  use FacetedSearch,
    sources: [
      books: [
        # options for the books table
      ],
      movies: [
        # options for the movies table
      ]
    ]
  ```

  ### joins {: .underline}

  Creates JOIN statements to collect data from other tables.

  - Type: `Keyword.t()`
  - Path: `sources > [source table] > joins`

  #### Key

  A unique name used as reference in other join and field definitions, and in the `scope_by` callback.
  By default, this is the name of the table being joined.
  When used as an alias, the `table` option is required.

  #### Value options

  - `table`
    - Table name.
    - Type: `atom`
    - Required if the key is an alias
  - `on`
    - Joins the table using an ON clause.
    - Type: `String.t()`
    - Required
  - `prefix`
    - Named schema if the referenced table is located in a schema other than "public".
    - Type: `String.t()`


  #### Examples

  By default, the key refers to the name of the table to be joined:

  ```
  sources: [
    books: [
      joins: [
        book_genres: [
          on: "book_genres.book_id = books.id"
        ],
        genres: [
          on: "genres.id = book_genres.genre_id"
        ]
      ]
    ]
  ]
  ```

  Here, the key `bkg` is used as an alias for the table `book_genres`:

  ```
  sources: [
    books: [
      joins: [
        bkg: [
          table: :book_genres,
          on: "bkg.book_id = books.id"
        ],
        genres: [
          on: "genres.id = bkg.genre_id"
        ]
      ]
    ]
  ]
  ```


  ### fields {: .underline}

  Lists all fields to be used in options `data_fields`, `text_fields` and `facet_fields`.
  Each entry includes the Ecto type and optional bindings.
  Under the hood, this defines Flop's custom fields.

  - Type: `Keyword.t()`
  - Path: `sources > [source table] > fields`

  #### Key

  A unique name used as reference in field definitions `data_fields`, `text_fields` and `facet_fields`.

  #### Value options

  - `ecto_type`
    - The Ecto type such as `:string` or `{:array, :string}`.
    - Type: `any()`
    - Required
  - `binding`
    - Name or alias of a joined table. Use togeter with option `field`.
    - Type: `atom()`
  - `field`
    - Referenced field of the joined table.
    - Type: `atom()`
    - Required: when using `binding`
  - `filter`
    - Identical to the Flop option, except that a default filter is applied by `FacetSearch`, making this option optional. If set, this option overrides the default filter.
    - From the Flop documentation:
      > A module/function/options tuple referencing a custom filter function. The function must take the Ecto query, the Flop.Filter struct, and the options from the tuple as arguments.
    - Type: `{atom(), atom(), Keyword.t()}`
  - `operators`
    - Identical to the Flop option.
    - From the Flop documentation:
      > Defines which filter operators are allowed for this field. If omitted, all operators will be accepted.
    - Type: `list(atom())`

  #### Examples

  In the simplest case, only `ecto_type` needs to be set:

  ```
  sources: [
    books: [
      fields: [
        title: [
          ecto_type: :string
        ]
      ],
      ...
    ]
  ]
  ```

  When extracting a value from a joined table, pass `binding` and `field`:

  ```
  sources: [
    books: [
      joins: [
        book_genres: [
          on: "book_genres.book_id = books.id"
        ],
        genres: [
          on: "genres.id = book_genres.genre_id"
        ]
      ],
      fields: [
        genre: [
          binding: :genres,
          field: :title,
          ecto_type: :string
        ]
      ],
      ...
    ]
  ]
  ```

  ### data_fields {: .underline}

  Fields to be used for filtering and data extraction in search results.
  The referenced fields populate the data column in the search view.

  Additionally, custom fields can be defined to generate data from other sources.

  - Type: `list(atom()) | list(Keyword.t())`
  - Path: `sources > [source table] > data_fields`

  #### List entries

  Either:

  - A field name of a field listed under option `fields`.
    - Type: `atom()`
  - A keyword list of field name/entry options to generate JSON data from joined tables (see examples below).
    - Type: `{atom(), Keyword.t()}`

  #### Examples

  In the simplest case, `data_fields` lists entries from `fields` to be included:

  ```
  sources: [
    books: [
      fields: [
        title: [
          ecto_type: :string
        ],
        author: [
          ecto_type: :string
        ]
      ],
      data_fields: [
        :title,
        :author_name
      ],
      ...
    ]
  ]
  ```

  To generate custom data, create definitions under the name key, similar to `fields`:

  ```
  data_fields: [
    ...
    genres: [
      id: [
        binding: :genres,
        field: :id
      ],
      definition: [
        binding: :genres,
        field: :definition
      ]
    ]
  ]
  ```

  Example with `joins` and `fields`:

  ```
  sources: [
    books: [
      joins: [
        book_genres: [
          on: "book_genres.book_id = books.id"
        ],
        genres: [
          on: "genres.id = book_genres.genre_id"
        ]
      ],
      fields: [
        title: [
          ecto_type: :string
        ],
        author: [
          ecto_type: :string
        ],
        genre: [
          binding: :genres,
          field: :title,
          ecto_type: :string
        ]
      ],
      data_fields: [
        :title,
        :author,
        genres: [
          id: [
            binding: :genres,
            field: :id
          ],
          definition: [
            binding: :genres,
            field: :definition
          ]
        ]
      ]
    ]
  ]
  ```

  ### text_fields {: .underline}

  A list of field names used for text search. Entries must be listed under `fields`.

  - Type: `list(atom())`
  - Path: `sources > [source table] > text_fields`

  #### List entries

  - A field name of a field listed under option `fields`.
    - Type: `atom()`

  #### Examples

  ```
  text_fields: [
    :author
  ]
  ```

  ### facet_fields {: .underline}

  A list of field names used to create facets.

  - Type: `list(atom())`
  - Path: `sources > [source table] > facet_fields`

  #### List entries

  - A field name of a field listed under option `fields`.
    - Type: `atom()`

  #### Examples

  ```
  facet_fields: [
    :publication_year,
    :genres
  ]
  ```

  ### sort_fields {: .underline}

  A list of fields used to for sorting.

  - Type: `list(atom()) | list(Keyword.t())`
  - Path: `sources > [source table] > sort_fields`


  #### List entries

  Either:

  - A field name of a field listed under option `fields`.
    - Type: `atom()`
  - A keyword list containing key `cast` to cast the orginal value to a sort value - see examples below.
    - Type: `{atom(), Keyword.t()}`

  #### Examples

  ```
  sort_fields: [
    :title,
    :publication_year
  ]
  ```

  Casting a string value to a float:

  ```
  sort_fields: [
    :title,
    publication_year: [
      cast: :float
    ]
  ]
  ```

  ### scopes {: .underline}

  Activates scoping the table contents. See: [Scoping data](README.md#scoping-data).

  ### prefix {: .underline}

  Use this when the source table is located in a database schema other than "public".

  - Type: `String.t()`
  - Path: `sources > [source table] > prefix`

  #### Example

  ```
  sources: [
    books: [
      prefix: "catalog"
      ...
    ]
  ]
  ```

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

      sortable_fields = FlopSchema.create_sortable_fields(options, custom_fields_option)

      sortable_option =
        Enum.concat(sortable_fields |> Enum.map(& &1.name), [:updated_at, :inserted_at])

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
        sortable: sortable_option
      }

      schema "faceted_search_document" do
        field(:id, :string)
        field(:source, :string)
        field(:data, :map)
        field(:text, :string)
        field(:inserted_at, :utc_datetime)
        field(:updated_at, :utc_datetime)

        Enum.each(sortable_fields, fn %{name: name, ecto_type: ecto_type} ->
          field(name, ecto_type)
        end)
      end

      @type t() :: %__MODULE__{
              # required
              id: String.t(),
              source: String.t(),
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
  Use together with option `scopes` under `source`. The list of scope keys are used
  to selectively call the `scope_by/2` callback functions.
  Each returned map is used to render a `WHERE` clause in the search view creation.

  See also: `create_search_view/3`.

  ## Examples

  If the schema module contains:

      defmodule KitchenJournalSchemas.FacetSchema do

          use FacetedSearch,
            sources: [
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
  If the seach view already exists, it will be dropped first.

  Options:
  - `scope` (optional) - The scope to be passed to the module function provided with option `scope_by` - see: [Supported options](#__using__/1-supported-options) under "sources".
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
  Returns the `FacetedSearch.SearchViewDescription` used to build the search view. Useful for debugging issues.

  ## Examples

      iex> FacetedSearch.search_view_description(MyApp.FacetSchema)
      %FacetedSearch.SearchViewDescription{}

  """
  @spec search_view_description(module()) :: SearchViewDescription.t()
  def search_view_description(module),
    do: module.search_view_description()

  @doc """
  The normalized Postgres materialized view name generated from `view_id`.
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
             from(ecto_schema)
             |> Flop.validate_and_run(params, for: MyApp.FacetSchema),
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
