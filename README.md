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
- Because search data is cached in a database view, searching may be a lot faster.

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
- `data` - A `jsonb` column that contains structured data for filtering. When handling search results, specific data can be extracted for rendering - for example a title and item details. Is it also possible to add custom data derived from other tables.
- `text` - A `text` column that contains a "bag of words" per row, used for text searches.
- `tsv` - A `tsvector` column used for generating facets (internal use).
- `inserted_at` - Source timestamp
- `updated_at` - Source timestamp

Additional sort columns are added when option `sort_fields` is used - see [Sorting](#sorting).

A single schema can generate different search views, each with its own scope - for example, a view per user or per media type.

Data from other tables can be included using join statements.

### Creating the search view

Set up the search view by passing a schema to `use FacetedSearch`.

The schema defines:

- From which tables to get data
- Which columns to use for filtering and data extraction, sorting and facets

See [Schema configuration](documentation/schema_configuration.md) for documentation and examples.

When the schema is defined, create the view with `FacetedSearch.create_search_view/3`.

### Updating the search view

A materialized view is essentially a cache: it provides faster search performance but must be refreshed to reflect changes in the source tables.

Updates could be performed periodically, or after after changes to the source tables - this should be decided at the application level.

Refreshing the view is done using `FacetedSearch.refresh_search_view/3`:

See also:

- `FacetedSearch.create_search_view_if_not_exists/3`.
- `FacetedSearch.drop_search_view/3`.

## Searching and filtering

### Searching with Flop

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
  ], %Flop.Meta{}}
}
```

### Limiting results data

You may need only a subset of the view columns. For example, to only return the data column, add a `select` statement:

```elixir
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "books")

from(ecto_schema)
|> select([schema], %{data: schema.data})
|> Flop.validate_and_run(params, for: MyApp.FacetSchema)
```

## Sorting

Sorting search results can be done in 2 ways:

1. Using Flop params
2. Using Ecto queries

### Sorting with Flop

Using Flop sort params is the simplest way to implement sorting, as the configuration can easily be defined in the application code and passed around as part of a Flop params map.

However, Flop requires that the specified fields refer to existing database columns. By using the [`sort_fields`](documentation/schema_configuration.md#sort_fields) schema option, additional columns are generated in the search view to facilitate this.

Schema example:

```elixir
use FacetedSearch,
  sources: [
    books: [
      ...
      sort_fields: [
        :title,
        :publication_year
      ]
    ]
  ]
```

To prevent conflicts with Flop (since custom fields, which are used internally, cannot be used for sorting),
the generated column names are prefixed with `sort_`. For example, a field `title` will have a corresponding sort column `sort_title` which should be used in the Flop params. Note that the field names in the schema don't use the prefix.

```elixir
params = %{
  filters: [...],
  order_by: [:sort_title],
  order_directions: [:asc]
}
```

#### Casting sort column values

Casting sort column values is useful when the original values aren’t suitable for sorting, for example, strings that represent numbers:

```elixir
iex> ["1.1", "1.2", "1.10"] |> Enum.sort()
["1.1", "1.10", "1.2"]
```

To define a cast operation, add `cast` to the sort field entry:

```elixir
sort_fields: [
  category: [
    cast: :float
  ]
]
```

The cast value can be any valid [Postgres data type](https://www.postgresql.org/docs/current/datatype.html). With non-standard types, results may vary.

As with Flop, multiple fields can be passed to `order_by` and `order_directions`.

### Sorting with Ecto

Sometimes more advanced sorting techniques are required. For example:

- Placing favorite items at the top
- Sorting by values extracted from the `data` column
- Prioritizing search matches in the result title

This can be implemented in the Ecto query that is passed to `Flop.validate_and_run`. Make sure to not pass Flop sort params at the same time.

Example to sort on a value stored in the `data` JSON:

```elixir
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "books")

from(ecto_schema)
|> order_by([schema],
  asc: fragment("?::jsonb->>'genre_title'", schema.data)
)
|> Flop.validate_and_run(params, for: MyApp.FacetSchema)
```

Similarly, to sort on matches in titles:

```elixir
|> order_by([schema],
  desc: fragment("similarity(?::jsonb->>'book_title', ?)", schema.data, ^query)
)
```

#### Using sort_fields with Ecto

It is also possible to use the generated sort columns described in [Sorting with Flop](#sorting-with-flop) with an Ecto query.

Assuming that `title` is listed under the `sort_fields` option:

```elixir
|> order_by([schema],
  asc: fragment("?::jsonb->>'genre_title'", schema.data),
  asc: :sort_title
)
```

## Faceted search

### Setup

Enabling faceted search involves the following steps:

- Configure the schema using the [`facet_fields`](documentation/schema_configuration.md#facet_fields) option
- Use `FacetedSearch.search/3` to perform the search
- Provide facet filters params to to update the search results based on selected facets

### Example facet search

`FacetedSearch.search/3` takes a reference to the schema and search params:

```elixir
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
{:ok, facets} = FacetedSearch.search(ecto_schema, params)
```

Utility function `FacetedSearch.ecto_schema/2` creates the reference using the schema and the view ID:

```elixir
iex> ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
{"fv_media", MyApp.FacetSchema}
```

### Combining Flop and facets

Facet search is typically combined with filters and text search. This means calling both `Flop.validate_and_run` and
`FacetedSearch.search` - see the following example.

Note that this function returns a three-element tuple that includes the facet results.

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

Usage example:

```elixir
params = %{filters: [
  %{field: :text, op: :ilike, value: "Le Guin"},
  %{field: :publication_year, op: :<=, value: 2000}
]}
{:ok, results, facets} = search_media(params)
{books, meta} = results
```

The returned `facets` data will look like this:

```elixir
[
 %FacetedSearch.FacetData.Facet{
   type: "value",
   field: :publication_year,
   facet_options: [
     %FacetedSearch.FacetData.FacetOption{value: "1968", count: 1, selected: false},
     %FacetedSearch.FacetData.FacetOption{value: "1971", count: 1, selected: false},
     %FacetedSearch.FacetData.FacetOption{value: "1972", count: 1, selected: false}
   ]
 }
]
```

Facets that don't have any hits will be omitted from the returned data.

### Facet filters

Facet filters are a specialized form of search filters:

- Selecting a single facet option activates the filter (the facet).
- Selecting multiple facet options within the same facet combines the option values using an OR condition.

To achieve this behavior using Flop, you need to adjust the filter settings slightly:

- The `value` must be an array.
- The operator `op` must be `:==`.
- Field names must be prefixed with `facet_`, so field `publication_year` becomes `facet_publication_year` in the search params. Note that the field names in the schema don't use the prefix.

#### Example search

Let's say we have added checkbox groups to the search page, showing 2 checkbox groups titled "Publication year" and "Author".

After the user has made a couple of selections, the search params may look like this:

```elixir
%{filters: [
  %{field: :facet_publication_year, op: :==, value: [2012,2014,2016]},
  %{field: :facet_author, op: :==, value: ["Yotam Ottolenghi"]}
]}
```

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
FacetedSearch.create_search_view(MyApp.FacetSchema, "books",
  scope: %{current_user: current_user})
```

#### Combining scopes

Using a list of scope keys, scope evaluation is AND-ed

Scopes can be created using any column in the source table — that is, the default view columns combined
with the columns defined in the [`data_fields`](documentation/schema_configuration.md#data_fields) option.

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

### Joining tables

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
        book_genres: [
          on: "book_genres.book_id = books.id"
        ],
        genres: [
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
  bg: [
    table: :book_genres,
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
        book_genres: [
          prefix: "catalog",
          on: "book_genres.book_id = books.id"
        ],
        genres: [
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
