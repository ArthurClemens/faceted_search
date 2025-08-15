# FacetedSearch

> **WARNING**
> This library is in its early stages: tests are not yet in place, and breaking changes are expected.

FacetedSearch integrates faceting into your application with [Flop ⤴](https://hexdocs.pm/flop) as the underlying search library.

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

## Background

Faceted search allows users to gradually refine search results by selecting filters based on structured fields
such as category, author, price range, and so on. Filters that would lead to zero results are hidden from the interface to prevent dead ends.

While faceted search was popularized by e-commerce platforms, many other types of applications can benefit from it. Some examples:

- Media libraries
- Medical care applications
- Course catalogs
- Scientific data repositories
- Fansites
- Admin interfaces

This FacetedSearch library aims to provide the tooling to bring faceted search to your Elixir application, using Elixir code and a Postgres database.

This brings the following benefits:

- Keeps all your data private, stored in your own database — no need to set up an external server or pay for a faceted search provider.
- Integrates seamlessly with an existing Flop setup, using the same concepts and functions.
- Combines faceted search with regular Flop-based filters and text search.
- Allows scoping per table, user, or any other scope you define.
- Because search data is cached in a database view, searching may be a lot faster.

## Library concepts

- Searching, filtering and faceting is performed on a "search view", a [materialized view ⤴](https://en.wikipedia.org/wiki/Materialized_view) that has searchable data cached in a database table.
- The search view is created from a [schema configuration](documentation/schema_configuration.md) that defines which database tables the data is fetched from.
- Searching and filtering is done using [Flop search ⤴](https://hexdocs.pm/flop) on the search view.
- [Faceted search](#faceted-search ↓) is performed with the same Flop search parameters. Facet results includes available facets and options, along with result counts, and can be used to create UI controls.

## The search view

### Properties

Data from one or more database tables and columns is aggregated into a "search view" - a materialized view.

The search view contains these base columns:

- `id` - A `string` column that contains the data source record ID - useful for navigation or performing additional database lookups.
- `source` - A `string` column that contains the data source table name.
- `data` - A `jsonb` column that contains structured data for filtering. When handling search results, specific data can be extracted for rendering - for example a title and item details. Is it also possible to add custom data derived from other tables.
- `text` - A `text` column that contains a "bag of words" per row, used for text searches.
- `tsv` - A `tsvector` column used for generating facets (internal use).
- `hierarchies` - A `jsonb` column that stores hierarchical data (internal use).
- `buckets` - A `jsonb` column that stores range bucket data (internal use).

Additional sort columns are added when option `sort_fields` is used - see [Sorting ↓](#sorting).

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

Refreshing the view is done using `FacetedSearch.refresh_search_view/3`.

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
      text: "A Wizard of Earthsea Ursula K. Le Guin"
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
        :publication_year,
        :title
      ]
    ]
  ]
```

To prevent conflicts with Flop (since custom fields, which are used internally, cannot be used for sorting),
the generated column names are prefixed with `sort_`. For example, a field `title` will have a corresponding sort column `sort_title` which should be used in the Flop params. Note that the field names in the schema don't use the prefix.

```elixir
params = %{
  filters: [...],
  order_by: [:publication_year, :sort_title],
  order_directions: [:desc, :asc]
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

The cast value can be any valid [Postgres data type ⤴](https://www.postgresql.org/docs/current/datatype.html).

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

It is also possible to use the generated sort columns described in [Sorting with Flop ↓](#sorting-with-flop) with an Ecto query.

Assuming that `title` is listed under the `sort_fields` option:

```elixir
|> order_by([schema],
  asc: fragment("?::jsonb->>'genre_title'", schema.data),
  asc: :sort_title
)
```

## Faceted search

So far, we've seen how to search, filter, and sort data from the search view using the Flop API. In this section we will expand this with facet data.

Getting facet results, and filtering using facets, involve the following steps:

1. Configure the schema with option `facet_fields`
2. Use `FacetedSearch.search` to perform the search.
3. Handle the facet results in the application.
4. Refine the search with facet selection

### 1. Configure the schema

Option [`facet_fields`](documentation/schema_configuration.md#facet_fields) configures the search view to store values from the listed fields. After performing a search, the collected facet results (containing value, label and count for each option) are then passed to the facet search results.

A simple schema entry with 2 facet fields would be:

```elixir
facet_fields: [
  :publication_year,
  :genres
]
```

### 2. Performing a facet search

`FacetedSearch.search/3` takes a reference to the schema and search parameters:

```elixir
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
{:ok, facets} = FacetedSearch.search(ecto_schema, params)
```

The utility function `FacetedSearch.ecto_schema/2` creates the reference using the schema and the view ID:

```elixir
iex> ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
{"fv_media", MyApp.FacetSchema}
```

The `ecto_schema` variable is an `Ecto.Queryable` and is used in building an Ecto query. Similar to
`from(u in Users)` we write `from(ecto_schema)`.

An Ecto query can be initialized with:

```elixir
ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
query = from(ecto_schema)
```

#### Combining Flop and facets

Facet search is typically combined with filters and text search. So it makes sense to combine both `Flop.validate_and_run` and
`FacetedSearch.search` in a single search function.

Note that this function returns a three-element tuple that includes the facet results.

```elixir
def search_media(search_params \\ %{}) do
  ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
  query = from(ecto_schema)

  with {:ok, flop_results} <-
         Flop.validate_and_run(query, search_params, for: FacetSchema),
       {:ok, facets} <-
         FacetedSearch.search(ecto_schema, search_params) do
    {:ok, flop_results, facets}
  else
    error -> error
  end
end
```

#### Usage example

If the user has typed "Le Guin" in the search box, the Flop parameters and search instructions will look like this:

```elixir
search_params = %{
  filters: [
    %{field: :text, op: :ilike, value: "Le Guin"},
  ],
  page_size: 10
}
{:ok, flop_results, facets} = search_media(search_params)
{books, meta} = flop_results
```

The returned facet results will look like this:

```elixir
[
  ...
  %FacetedSearch.Facet{
    field: :publication_year,
    options: [
      %FacetedSearch.Option{value: 1964, label: "1964", count: 2, selected: false},
      %FacetedSearch.Option{value: 1966, label: "1966", count: 2, selected: false},
      %FacetedSearch.Option{value: 1967, label: "1967", count: 1, selected: false},
      %FacetedSearch.Option{value: 1968, label: "1968", count: 1, selected: false},
      ...
    ],
    ...
  }
]
```

Facets that don't have any hits will be omitted from the returned data.

### 3. Handling facet results

The facet results can be used to create facet UI controls to show the current facet filter state, and on selection, trigger a new search.

UI controls are outside of the scope of this library; this section describes the data elements that support creating them.

```elixir
[
  %FacetedSearch.Facet{
    field: :publication_year,
    options: [
      %FacetedSearch.Option{value: 1964, label: "1964", count: 2, selected: false},
      ...
    ],
    ...
  },
  ...
]
```

#### Option: value

The `value ` field contains the data from a table's column, cast to the `ecto_type` defined in schema `fields`. Its main use is to set the filter value - see [Facet selection ↓](#4-facet-selection). The value is also useful for sorting the list of options in case their values are numeric.

#### Option: label

The `label` field contains the string value of the `value` field, unless configured otherwise. See [Option labels ↓](#option-labels). 

#### Option: count

The `count` field corresponds to the the number of rows with the column value with current search filters applied. The count is frequently used in faceted search UI's, but also often left out to reduce clutter.

#### Option: selected

The `selected` field simply stores the selected state of the applied filter.
 
### 4. Facet selection

Selected facet options are translated to additional search filters, using the configured [schema configuration: facet_fields](documentation/schema_configuration.md#facet_fields).

#### Facet filters

Facet filters are a specialized form of search filters:

- Selecting a single facet option activates the facet (the filter).
- Selecting multiple facet options from different facets combines the option values using an AND condition.
- Selecting multiple facet options within the same facet combines the option values within that facet using an OR condition. When a facet contains at least one selected option, the other options within the facet stay available.

To achieve this behavior using Flop, we need to create filters using the following rules:

- Field names must be prefixed with `facet_`, so field `publication_year` becomes `facet_publication_year` in the search parameters.
  - Note that the field names in the schema don't use the prefix.
- The `value` must be an array.
- The operator `op` must be `:==`.

#### Example search

If we provide a checkbox group to the search page to select the publication year (not the best UI - see [Ranges](#ranges) for a better alternative), and the user has typed "Le Guin" in the search box, and selected the years 1964 and 1966, the Flop search parameters will look like this:

```elixir
%{filters: [
  %{field: :text, op: :ilike, value: "Le Guin"},
  %{field: :facet_publication_year, op: :==, value: [1964, 1966]},
]}
```

The returned facet results will look like this:

```elixir
[
  %FacetedSearch.Facet{
    field: :publication_year,
    options: [
      %FacetedSearch.Option{value: 1964, label: "1964", count: 2, selected: true},
      %FacetedSearch.Option{value: 1966, label: "1966", count: 2, selected: true},
      %FacetedSearch.Option{value: 1967, label: "1967", count: 1, selected: false},
      %FacetedSearch.Option{value: 1968, label: "1968", count: 1, selected: false},
      ...
    ],
    ...
  }
]
```

## Option labels

Instead of displaying the option values, option labels may contain texts that are better suited for a user interface. 

Two scenarios are supported:
1. A database table provides text representations - for example, product names, genre titles, user roles, etc.
2. Custom text is needed, and it's preferable that UI components do not have to process the option values themselves.

### Labels from database tables

In the schema configuration for `facet_fields`, option `label` references a field to read the label text from:

```elixir
facet_fields: [
  genres: [
    label: :genre_title
  ]
]
```

See [schema configuration: facet_fields](documentation/schema_configuration.md#facet_fields) for details.

### Custom labels

In the schema module, callback `option_label/3` creates label texts for a given value or database label:

```elixir
defmodule MyApp.FacetSchema do

  def option_label(:favorite, value, _) do
    if value, do: "Yes", else: "No"
  end

  def option_label(:user_roles, value, _) do
    case value do
      :admin -> gettext("Admin")
      :support -> gettext("Support")
      :qa -> gettext("Q&A")
      _ -> value
    end
  end

  def option_label(:languages, value, database_label) do
    case value do
      "en" -> "English (UK)"
      _ -> database_label
    end
  end
  
  def option_label(_, _, _), do: nil

  ...
```

- See [Callbacks: option_label/3](FacetedSearch.html#c:option_label/3) for details
- See [Ranges ↓](#ranges) for an example with range values

## Ranges

Ranges divide numerical and date entries into distinct categories (buckets), for example: movies created between 2000 and 2010, prices from EUR 0 to 10, items modified since last week, etc.

### Configuration

In the schema configuration for `facet_fields`, use range bound options to define the bounds of the buckets.

-  `number_range_bounds` - for numerical data
-  `date_range_bounds` - for dates, timestamps, and intervals

When using date ranges, refresh the search view at least as often as the smallest configured interval to avoid outdated values.

#### Example with numerical data

```elixir
facet_fields: [
  publication_year: [
    number_range_bounds: [1980, 2000, 2020]
  ]
]
```

Note that the `publication_year` value in the facet results now contains the bucket number instead of the year.

#### Example with dates

This example assumes `updated_at` is defined in `fields`.

```elixir
facet_fields: [
  updated_at: [
    date_range_bounds: [
      "2025-01-01",
      "now() - interval '1 month'",
      "now() - interval '1 week'",
      "now() - interval '1 day'"
    ]
  ]
]
```

- See [schema configuration: facet_fields](documentation/schema_configuration.md#facet_fields) for details.
- See [Postgres Date/Time Functions and Operators ⤴](https://www.postgresql.org/docs/current/functions-datetime.html) to get further ideas for date range values.

### Filtering range facets

For a range facet, the option value in the facet results contains the bucket number. Bucket numbers starts at 0, so values 2 and 3 correspond to the range bounds "1 week" and "1 day" above. 

```elixir
%{filters: [
  %{field: :facet_publication_year, op: :==, value: [2, 3]},
]}
```

### Range labels

Use the callback function `option_label/3` described at [custom labels](#custom-labels) to create readable option labels for ranges.

The value passed to the callback contains a tuple containing:
- The lower and upper bound:
  - The bound value
  - `:lower` indicates: lower than (or before) the first bound
  - `:upper` indicates: higher than (or after) the last bound
- The bucket number

With the range bounds in the example above, the values are:

```elixir
{[:lower, 1980], 0}
{[1980, 2000], 1}
{[2000, 2020], 2}
{[2020, :upper], 3}
```

Example of `option_label` callback for ranges configured with `number_range_bounds`:

```elixir
def option_label(:publication_year, value, _) do
  {bounds, _bucket} =  value

  case bounds do
    [:lower, to] -> "before #{to}"
    [from, :upper] -> "after #{from}"
    [from, to] -> "#{from}-#{to}"
  end
end
```

Example of `option_label` callback for ranges configured with `date_range_bounds` - with the configuration described above:

```elixir
def option_label(:updated_at, value, _) do
  {bounds, _bucket} = value

  case bounds do
    [:lower, "2025-01-01"] -> "before 1 Jan 2025"
    ["2025-01-01", "now() - interval '1 month'"] -> "between 1 Jan 2025 and last month"
    ["now() - interval '1 month'", "now() - interval '1 week'"] -> "last month"
    ["now() - interval '1 week'", "now() - interval '1 day'"] -> "last week"
    ["now() - interval '1 day'", :upper] -> "today"
  end
end
```

## Hierarchies / categories

Hierarchical facets allow users to refine their search step-by-step by navigating a tree-based data structure such as a product catalog.

An art catalog might have the categorization: `Art periods → Modern art → Pop art`. When using hierarchical facets, option "Pop art" becomes available only after selecting "Modern art".
  
Hierarchical facets are generated in the same way as regular facets, with these differences:
- A parent relation is added automatically based on the paths (unless option `parent` is used to point to a specific field).
- Option values are strings, containing the path values separated by ">", for example: "modern_art>pop_art".
 
### Configuration

Hierarchical facets are configured under a special entry `hierarchies` - below this, the settings are the same as for regular facets, with these differences:
- The entry name is custom, and does not need to reference a existing field.
- Key `path` contains the list of fields that creates the hierarchy.

Taking the art catalog example from above (assuming fields `art_periods` and `art_movements` exist), the configuration could look like this:

```elixir
facet_fields: [
  ...
  hierarchies: [
    periods: [
      path: [:art_periods]
    ],
    movements: [
      path: [:art_periods, :art_movements]
    ]
  ]
]
```

Hierarchy paths can be created in any order. For example:
- `Art form → Medium → Artist`
- `Artist → Medium → Art form`

Translated to the schema configuration:

```elixir
facet_fields: [
  hierarchies: [
    by_art_form: [
      path: [:art_forms, :art_media, :artists]
    ],
    by_artist: [
      path: [:artists, :art_media, :art_forms]
    ]
  ]
]
```

### Filtering hierarchical facets

To get modern artworks, filter on facet `periods`:

```elixir
%{filters: [
  %{field: :facet_periods, op: :==, value: ["modern_art"]}
]}
```

To get pop art works, filter on facet `movements` and its option value - in this case "modern_art>pop_art". The parent facet `periods` with value "modern_art" will be selected automatically.

```elixir
%{filters: [
  %{field: :facet_movements, op: :==, value: ["modern_art>pop_art"]},
]}
```

To remove parent facet `periods` from the facet results, set its option `hide_when_selected` to `true`

### Hierarchy labels

See [Option labels](#option-labels)

To create a custom text (which cannot be read from the database), use the callback function `option_label/3` described at [custom labels](#custom-labels) to create readable option labels for hierarchies.

The received value will contains the path values separated by ">", for example: "modern_art>pop_art".

Example:

```elixir
def option_label(:movements, value, label) do
  movements_value = value |> String.split(">") |> List.last()
  
  case movements_value do
    "pop_art" -> gettext("Pop art")
    _ -> label
  end
end
```

## Performance

When the search view grows to a substantial number of rows, additional performance tweaking will be needed. At what point exactly should be established empirically - it depends on the complexity of the data, or whether or not facets or sorting are used.

When using facets, retrieving facet data takes up the bulk of the query time: it involves two extra database queries on the `tsv` column where all rows are filtered and grouped. When querying more than 100,000 rows, this adds up.

### Built-in optimizations

FacetedSearch contains two optimizations:

- All columns in the search view are indexed.
- If no facet filters are applied, the second query on the `tsv` column for retrieving filtered facet results is skipped. This should make the initial search page load slightly faster when no facets are selected.

### Measuring query time

Query performance can be measured using `:timer.tc/1` to wrap the search function:

```elixir
:timer.tc(fn ->
  search_media(search_params)
)
```

The returned query time is measured in microseconds, so divide by 1,000 to get milliseconds.

A rough performance goal for a search query is to take less than 300ms.

### Optimizing queries

#### Scoping

One way to improve query time is to break up a single search view into multiple ones, each scoped with a filter.

This is common in ecommerce: instead of searching in everything, the user is first guided through main categories or even subcategories before facets are even offered. 

The idea of scoped search views is that the number of rows are smaller, resulting in faster search responses, and that facets can be made more specific to the subdomain.

See [Scoping data ↓](#scoping-data) for details.

#### Caching

Query results can be cached, see [Caching facet results ↓](#caching-facet-results).

#### Working around common text searches

Because of input variations, text searches are hard to optimize using caching, even more so when results are displayed as you type (debounced results). Or it would require a large number of caches, which should be avoided too.

One way is to translate a text query to a filtered query. For example, “blue trousers” can be interpreted as filters "apparel:trousers" and "color:blue". The user is then redirected to the category page with filters applied, and cached results are displayed.

## Caching facet results

GenServer `FacetSearch.Cache` handles caching of facet results. Data is cached in an [ETS table ⤴](https://hexdocs.pm/elixir/main/ets.html), where the cache key is the combination of the search view name and the used filters.

When the search view is updated, any exsisting cache that contains a key with the search view name is automatically cleared. Alternatively, call `FacetedSearch.clear_facets_cache/1`.

The cache is only written and read when option `cache_facets` is `true` - see below.

### Setup caching

1. Add `FacetSearch.Cache` to a supervisor (typically in `application.ex`):
   ```elixir
   children = [
     {FacetSearch.Cache, []}
     ...
   ]

   Supervisor.start_link(children, options)
   ```
2. Enable caching of results from filter parameters by calling `FacetedSearch.search/3` with option `cache_facets` set to `true`.

### Cache warming

Caches can be created upfront, by passing a list of filters to `FacetedSearch.warm_cache/2`.

For example:

```elixir
search_params_to_cache = [
  %{filters: [%{field: :apparel, value: "men", op: :==}]}
  %{filters: [%{field: :apparel, value: "women", op: :==}]}
  %{filters: [%{field: :apparel, value: "unisex", op: :==}]}
  %{filters: [%{field: :facet_colors, value: ["blue"], op: :==}]},
]

ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, view_id)
FacetedSearch.warm_cache(ecto_schema, search_params_to_cache)
```

Note: cached data, including from a warmed cache, is only returned when option `cache_facets` is set to `true`.

### Example of conditional caching

Builing upon the example search function from before, we add conditional caching with the following logic:
- Don't cache when text search is invoked
- Only cache when the result count is greater than 1,000

```elixir
def search_media(search_params \\ %{}) do
  ecto_schema = FacetedSearch.ecto_schema(MyApp.FacetSchema, "media")
  query = from(ecto_schema)
  is_text_search = Enum.any?(search_params.filters, &(&1.field == :text))

  with {:ok, {_results, meta} = flop_results} <-
         Flop.validate_and_run(query, search_params, for: FacetSchema),
       cache_facets <- not is_text_search and meta.total_count > 1_000,
       {:ok, facets} <-
         FacetedSearch.search(ecto_schema, search_params, cache_facets: cache_facets) do
    {:ok, flop_results, facets}
  else
    error -> error
  end
end
```

## Scoping data

Scoping is the method of filtering search view data upfront, in order to create multiple search views.

This is useful:
- When working with large datasets, where data can be split up in separate logical parts, for example items filtered by category, source or date.
- In multi-tenant applications, where each user or tenant should only have access to a specific subset of the data.

A scope is created in three steps:

1. By providing the schema option `scope_keys` with a list of scope identifiers.
2. By writing callback function `scope_by/2`, defined in the same schema module where `use FacetedSearch` is called. The first parameter is the scope identifier.
3. By calling `FacetedSearch.create_search_view/3` with option `scopes`, containing any value that `scope_by/2` should handle.

### Example: scoping to the current user

#### 1. Pass `scope_keys` to the `source` option:

```elixir
scope_keys: [:current_user],
```

#### 2. Define the callback:

```elixir
def scope_by(:current_user, %{current_user: current_user} = _scopes) do
  %{
    field: :user_id,
    comparison: "=",
    value: current_user.id
  }
end
```

The value at key `field` should reference either a column from the sources table, or a field listed in `fields`.

#### 3. Pass the scope to `FacetedSearch.create_search_view/3`:

```elixir
FacetedSearch.create_search_view(MyApp.FacetSchema, "books",
  scopes: %{current_user: current_user})
```

### Combining scopes

Using a list of scope keys, scope evaluation is AND-ed

Scopes can be created using any column in the source table — that is, the default view columns combined
with the columns defined in the [`data_fields`](documentation/schema_configuration.md#data_fields) option.

For example, to scope by publication year, limiting the table to the current user and to books published after 2018, add both scope keys:

```elixir
scope_keys: [:current_user, :publication_year],
```

Define the filter callbacks:

```elixir
def scope_by(:current_user, scopes) do
  %{
    field: :user_id,
    comparison: "=",
    value: scopes.user.id
  }
end

def scope_by(:publication_year, scopes) do
  %{
    field: :publication_year,
    comparison: ">",
    value: scopes.publication_year
  }
end
```

Create the scoped search view:

```elixir
FacetedSearch.create_search_view(
  MyApp.FacetSchema,
  "user-books-after-2018",
  scopes: %{user: current_user, publication_year: 2018}
)
```

## Multiple sources

When multiple resources share common attributes, a unified search interface allows users to search across all of them and use the resource type itself as a facet. For example, in a media library containing books, movies, and music, each item has a title, author or creator, publishing date, and genre. The media type can then serve as one of the filters in the search.

To create such a unified interface for resources with similar attributes, add a configuration for each resource under `sources`, using the resource’s table name as the key.

See [schema configuration: sources](documentation/schema_configuration.md#sources) for details.

## Joining tables

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
FacetedSearch.create_search_view(MyApp.FacetSchema, user.id, [scopes: %{current_user: user}, prefix: "user_catalogs"])
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
  query = from(ecto_schema)

  with {:ok, flop_results} <-
         Flop.validate_and_run(query, params, for: MyApp.FacetSchema, query_opts: [prefix: prefix]),
       {:ok, facets} <- FacetedSearch.search(ecto_schema, params, query_opts: [prefix: prefix]) do
    {:ok, flop_results, facets}
  else
    error -> error
  end
end
```
