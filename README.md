# FacetedSearch

> **WARNING**
> This library is in its early stages: tests are not yet in place, and breaking changes are expected.

FacetedSearch integrates faceting into your application with [Flop](https://hexdocs.pm/flop) as the underlying search library.

Faceted search allows users to gradually refine search results by selecting filters based on structured fields
such as category, author, price range, and so on. Filters that would lead to zero results are hidden from the interface to prevent dead ends.

Key benefits include:

- Keeps all your data private, stored in your own database — no need to set up an external server or pay for a faceted search provider.
- Integrates seamlessly with an existing Flop setup, using the same concepts and functions.
- Combines faceted search with regular Flop-based filters and text search.
- Allows scoping per table, user, or any other scope you define.

## Installation

Add `faceted_search` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:faceted_search,
      git: "https://github.com/ArthurClemens/faceted_search.git",
      branch: "development"
    }
  ]
end
```

## Overview

- Searching, filtering and faceting is performed on a "search view", a materialized database view that has searchable data cached in a database table.
- The search view is created using a configuration that defines which current database tables the data is fetched from.
- Searching and filtering is done using Flop search on the search view table.
- Faceting is done with `FacetedSearch.search/3`, using the same Flop params. Facet results can be used to create facet controls, such as checkbox groups.

## The search view

### Properties

Data from one or more database tables and columns is aggregated into a "search view" - a materialized database view.

The search view contains these base columns:

- `id` - A `string` column that contains the data source record ID - useful for navigation or performing additional database lookups.
- `source` - A `string` column that contains the data source table name.
- `data` - A `jsonb` column that contains structured data for filtering. When handling search results, specific data can be extracted for rendering a title and item details.
- `text` - A `text` column that contains a "bag of words" per row, used for text searches.
- `tsv` - A `tsvector` column used for generating facets (internal use).
- `inserted_at` - Source timestamp
- `updated_at` - Source timestamp

Additional sort columns are added when option `sort_fields` is used - see [Sorting](#sorting).

A single schema can generate different search views, each with its own scope - for example, a view per user or per media type.

Data from other tables can be included using join statements.

### Creating the search view

Assuming we have a source of books with attributes author, year of publication and genre.
We can use Flop filtering and search to:

- Find books by title
- Find book authors by name
- Filter books by publication year

We now want to enhance the search options with faceted search that allows to:

- Filter books by one or more publication years

In the sections below we'll be setting up a basic search view schema, creating the search view and running queries.

After that, we will add:

- Multiple sources
- Scoping data
- Joining other tables

### Example schema

The corresponding options would be:

```elixir
module MyApp.FacetSchema do

  use FacetedSearch,
    sources: [
      books: [
        fields: [
          title: [
            ecto_type: :string
          ],
          author: [
            ecto_type: :string
          ],
          publication_year: [
            ecto_type: :integer
          ]
        ],
        data_fields: [
          :title,
          :author,
          :publication_year
        ],
        text_fields: [
          :title,
          :author
        ],
        facet_fields: [
          :publication_year
        ]
      ]
    ]

end
```

Create the view with `FacetedSearch.create_search_view/3`.

```elixir
FacetedSearch.create_search_view(MyApp.FacetSchema, "books")
```

The database will now contain a materialized view named "fv_books".

### Updating the search view

A materialized view is essentially a cache: it provides faster search performance but must be refreshed to reflect changes in the source tables.

Updates could be performed periodically, or after after changes to the source tables - this should be decided at the application level.

Refreshing the view is done using `FacetedSearch.refresh_search_view/3`:

```elixir
FacetedSearch.refresh_search_view(MyApp.FacetSchema, "media")
```

See also:

- `FacetedSearch.create_search_view_if_not_exists/3`.
- `FacetedSearch.drop_search_view/3`.

## Searching and filtering

We can query the search view using Flop filters. For example, to perform a text search on author name and filter by publication year:

```elixir
params = %{filters: [
  %{field: :text, op: :ilike, value: "Le Guin"},
  %{field: :publication_year, op: :<=, value: 2000}
]}

ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "books")
Flop.validate_and_run(ecto_schema, params, for: MyApp.FacetSchema)
```

Example result:

```elixir
{:ok,
  {[
    %MyApp.FacetSchema{
      id: "019784c7-369a-7753-9f8c-2258add27f46", # referenced book id in table "books"
      source: "books",
      data: %{
        "author" => "Ursula K. Le Guin",
        "publication_year" => 1968,
        "title" => "A Wizard of Earthsea"
      },
      text: "A Wizard of Earthsea Ursula K. Le Guin",
      inserted_at: # source timestamp
      updated_at: # source timestamp
    },
    ...
  ],
  %Flop.Meta{}
}
```

### Limiting results data

You may need only a subset of the view columns. For example, to only return the data column, add a `select` statement:

```elixir
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "books")

from(ecto_schema, as: :schema)
|> select([schema], %{data: schema.data})
|> Flop.validate_and_run(params, for: MyApp.FacetSchema)
```

## Sorting

Sorting is enabled with schema source option `sort_fields` and referencing fields that are listed under `fields`.

```elixir
use FacetedSearch,
  sources: [
    books: [
      fields: [
        title: [
          ecto_type: :string
        ],
        author: [
          ecto_type: :string
        ],
        publication_year: [
          ecto_type: :integer
        ]
      ],
      ...
      sort_fields: [
        :title,
        :publication_year
      ]
    ]
  ]
```

This will create additional columns in the search view. To prevent conflicts with Flop,
the column names are prefixed with `sort_`. For example, field `title` will have a corresponding sort column `sort_title`.

Example Flop params with `order_by`:

```elixir
params = %{
  filters: [%{field: :text, op: :ilike, value: "Le Guin"}],
  order_by: [:sort_publication_year]
}
```

## Faceted search

Facet filters are a specialized form of search filters:

- Selecting a single facet option activates the filter (the facet).
- Selecting multiple facet options within the same facet combines the option values using an OR condition.

To achieve this behavior using Flop, you need to adjust the filter settings slightly:

- Field names must be prefixed with `facet_`, so `field: :publication_year` becomes `field: :facet_publication_year`.
- The operator `op` must be `:==`.
- The `value` must be an array.

Examples:

```elixir
%{filters: [%{field: :facet_publication_year, op: :==, value: [2012,2014,2016]}]}
%{filters: [%{field: :facet_author, op: :==, value: ["Yotam Ottolenghi"]}]}
```

Examples combining regular Flop filters with facet filters:

```elixir
%{filters: [%{field: :text, op: :ilike, value: "simple"}, %{field: :facet_publication_year, op: :==, value: [2012,2014,2016]}]}
```

The same Flop params are passed to both `Flop.validate_and_run` and `FacetedSearch.search`.

### Example search function

```elixir
def search_media(params \\ %{}) do
  ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")

  with {:ok, results} <-
         from(ecto_schema) |> Flop.validate_and_run(params, for: MyApp.FacetSchema),
       {:ok, facets} <- FacetedSearch.search(ecto_schema, params) do
    {:ok, results, facets}
  else
    error -> error
  end
end
```

### Example search

```elixir
params = %{filters: [%{field: :facet_publication_year, op: :==, value: [2018]}]}
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
{:ok, facets} <- FacetedSearch.search(ecto_schema, params)
```

### Example result

```elixir
{:ok,
 [
   %FacetedSearch.FacetData.Facet{
     type: "value",
     field: :publication_year,
     facet_options: [
       %FacetedSearch.FacetData.FacetOption{value: "2010", count: 1, selected: false},
       %FacetedSearch.FacetData.FacetOption{value: "2016", count: 2, selected: false},
       %FacetedSearch.FacetData.FacetOption{value: "2018", count: 1, selected: true}
     ]
   }
 ]}
```

Facets that don't have any hits will be omitted from the results.

## Additional search view functionality

### Multiple sources

TODO

### Scoping data

Limiting the data in a search view is useful when working with large datasets or in multi-tenant applications,
where each user or tenant should only have access to a specific subset of the data.

A scope is defined using three components:

1. The `scopes` option, which contains a list of scope identifiers.
2. A callback function `scope_by/2`, defined in the same schema module where `use FacetedSearch` is called. The first parameter is the scope identifier.
3. The `scope` option passed to `FacetedSearch.create_search_view/3`, containing any value that `scope_by/2` should handle.

#### Example: scoping to the current user

1. Pass `scopes` to the `source` option:

```elixir
scopes: [:current_user],
```

2. Define the callback:

```elixir
@behaviour FacetedSearch
def scope_by(:current_user, %{current_user: current_user} = _scope) do
  %{
    field: :user_id,
    comparison: "=",
    value: current_user.id
  }
end

def scope(:other_scope_key, scope) do
  ...
end
```

Note that map key "field" references the table from "sources".

3. Pass the scope to `FacetedSearch.create_search_view/3`:

```elixir
FacetedSearch.create_search_view(MyApp.FacetSchema, "books", scope: %{current_user: current_user})
```

#### Combining scopes

Using a list of scope keys, scope evaluation is AND-ed

Scopes can be created using any column in the source table — that is, the default view columns combined
with the columns defined in the `data_fields` option.

For example, to scope by publication year, limiting the table to the current user and to books published after 2018, add both scope keys:

```elixir
scopes: [:current_user, :publication_year],
```

Define the filter callbacks:

```elixir
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
```

Create the scoped search view:

```elixir
FacetedSearch.create_search_view(
  MyApp.FacetSchema,
  "user-books-after-2018",
  scope: %{user: current_user, publication_year: 2018}
)
```

### Joining other tables

To continue with the books example, we would like to add genres to the search table.

- An existing table "genres" is associated with the "books" table through an intermediate table called "book_genres".
- A book can have multiple genres assigned.
- For filtering, we pick the "name" column.

Let's add these with the options `joins` and `field`.

```elixir
use FacetedSearch,
  sources: [
    books: [
      joins: [
        [
          table: :book_genres,
          on: "book_genres.book_id = books.id"
        ],
        [
          table: :genres,
          on: "genres.id = book_genres.genre_id"
        ]
      ],
      fields: [
        ...
        genres: [
          binding: :genres,
          field: :name,
          ecto_type: {:array, :string}
        ]
      ],
      data_fields: [
        :author,
        :genres
      ],
      text_fields: [
        :author
      ],
      facet_fields: [
        :publication_year,
        :genres
      ]
    ]
  ]
```

Note that you can use aliases for joined fields. This is mostly useful when referencing a joined table multiple times.

```elixir
joins: [
  [
    table: :book_genres,
    as: :bg,
    on: "bg.book_id = books.id"
  ]
]
```

The genres data contains an array of strings. To find matches, we use `ilike_or`:

```elixir
params = %{filters: [
  %{field: :genres, op: :ilike_or, value: ["fantasy"]},
  %{field: :publication_year, op: :<=, value: 2000}
]}
```

## Multi-tenancy and prefix

Pass the `prefix` option to the schema and to create, refresh, and search functions.

### Examples

#### Creating the search view schema

```elixir
use FacetedSearch,
  sources: [
    books: [
      prefix: "catalog",
      joins: [
        [
          table: :book_genres,
          prefix: "catalog",
          on: "book_genres.book_id = books.id"
        ],
        [
          table: :genres,
          prefix: "catalog",
          on: "genres.id = book_genres.genre_id"
        ]
      ],
      ...
    ]
  ]
```

#### Creating a view

```elixir
FacetedSearch.create_search_view(MyApp.FacetSchema, "media", prefix: "catalog")
FacetedSearch.create_search_view(MyApp.FacetSchema, user.id, [scope: %{current_user: user}, prefix: "user_catalogs"])
```

#### Refreshing a view

```elixir
FacetedSearch.refresh_search_view(MyApp.FacetSchema, "media", prefix: "catalog")
```

#### Searching

To align with Flop options, the `prefix` option is wrapped inside `query_opts`:

```elixir
{:ok, facets} <- FacetedSearch.search(ecto_schema, params, query_opts: [prefix: prefix])
```

Example search function with prefix options:

```elixir
def search_media(params \\ %{}, opts \\ []) do
  prefix = Keyword.get(opts, :prefix)
  ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")

  with {:ok, results} <-
         from(ecto_schema) |> Flop.validate_and_run(params, for: MyApp.FacetSchema, query_opts: [prefix: prefix]),
       {:ok, facets} <- FacetedSearch.search(ecto_schema, params, query_opts: [prefix: prefix]) do
    {:ok, results, facets}
  else
    error -> error
  end
end
```
