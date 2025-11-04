# Schema configuration

Defines the database schema for the search view. Pass the schema configuration via the options of `use Fase`.

Create a module to contain the schema, for example `MyApp.FacetSchema`:

```
defmodule MyApp.FacetSchema do

  use Fase, [
    # configuration options
  ]

end
```

Minimal schema example:

```
use Fase,
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

## id

Top level settings for the `id` column.

- Type: `list(Keyword.t())`
- Path: `id` (schema root)
- Optional

### Value options

- `unique_index` - Set to `true` to create a unique index on the id column; by default `false`. Should not be true if `group_by` is used.
- `transforms`
  - Type to cast or transform the value
  - Type: `list(String.t())`

## sources

Settings per resource. The source key refers to the name of a resource table in your repo.

- Type: `list(Keyword.t())`
- Path: `sources` (schema root)
- Required

The source ID's must be unique.

### Example

```
use Fase,
  sources: [
    books: [
       # options for the books table
    ],
    movies: [
       # options for the movies table
    ]
  ]
```

## joins

Creates JOIN statements to collect data from other tables.

- Type: `Keyword.t()`
- Path: `sources > [source table] > joins`

### Key

A unique name used as reference in other join and field definitions, and in the `scope_by` callback.
By default, this is the name of the table being joined.
When used as an alias, the `table` option is required.

### Value options

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

### Examples

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

## group_by

Optional setting for the "GROUP BY" statement.

- Type: `String.t()`
- Path: `sources > [source table] > group_by`

### Example

```
sources: [
  articles: [
    joins: [
      author_articles: [
        on: "author_articles.article_id = articles.id"
      ],
      authors: [
        on: "authors.id = author_articles.author_id"
      ],
    ],
    group_by: "articles.id, authors.id",
    ...
  ]
]
```

## fields

Lists all fields to be used in options `data_fields`, `text_fields` and `facet_fields`.
Each entry includes the Ecto type and optional bindings.
Under the hood, this defines Flop's custom fields.

- Type: `Keyword.t()`
- Path: `sources > [source table] > fields`

### Key

A unique name used as reference in field definitions `data_fields`, `text_fields` and `facet_fields`.

### Value options

- `ecto_type`
  - The Ecto type such as `:string` or `{:array, :string}`.
  - Type: `any()`
  - Required
- `binding`
  - Name of a joined table or the source table. Use togeter with option `column`. If not specified, the source table is assumed.
  - Type: `atom()`
- `column`
  - Referenced column of the joined table or the source table.
  - Type: `atom()`
  - Required: when using `binding`
- `filter`
  - Identical to the Flop option, except that a default filter is applied by `Fase`, making this option optional. If set, this option overrides the default filter.
  - From the Flop documentation:
    > A module/function/options tuple referencing a custom filter function. The function must take the Ecto query, the Flop.Filter struct, and the options from the tuple as arguments.
  - Type: `{atom(), atom(), Keyword.t()}`
- `operators`
  - Identical to the Flop option.
  - From the Flop documentation:
    > Defines which filter operators are allowed for this field. If omitted, all operators will be accepted.
  - Type: `list(atom())`

### Examples

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

When extracting a value from a joined table, pass `binding` and `column`:

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
        column: :title,
        ecto_type: :string
      ]
    ],
    ...
  ]
]
```

Also pass `binding` and `column` when creating an alias for a source table column. In this example we
create the alias `author_name` from `books.author`, so that we can reference it in `data_fields` and so on.

```
sources: [
  books: [
    fields: [
      author_name: [
        binding: :books,
        column: :author,
        ecto_type: :string
      ]
    ],
    data_fields: [
      :author_name
    ],
    ...
  ]
]
```

## data_fields

Fields to be used for filtering and displaying details in search results.
The referenced fields populate the `data` column in the search view.

Additionally, custom fields can be defined to generate data from other sources.

The values of these fields may be optionally transformed.

- Type: `list(atom()) | list(Keyword.t())`
- Path: `sources > [source table] > data_fields`

### List entries

Either:

- A field name from option `fields`.
  - Type: `atom()`
- A keyword list:
  - Key: a field name from option `fields`
  - Values:
    - A keyword list with key `transforms`:
      - Type: `list(String.t())`
    - A keyword list with key `ecto_type`
      - Only if the transforms result in a different type than defined in `fields`
      - The Ecto type such as `:string` or `{:array, :string}`.
      - Type: `any()`
- A keyword list of field name/entry options to generate JSON data from joined tables or fields listed in the `fields` option.

Entry options are either:

- The name of a field listed in the `fields` option
  - Type: `atom()`
- A keyword list with keys:
  - `binding`
    - Name or alias of a joined table. Use togeter with option `column`.
    - If no binding is used, they entry key is used to look up the column from the `fields` option.
    - Type: `atom()`
  - `column`
    - Referenced column of the joined table.
    - Type: `atom()`
    - Required: when using `binding`
  - `transforms`
    - Type to cast or transform the value
    - Type: `list(String.t())`

### Examples

In the simplest case, `data_fields` lists entries from the `fields` option:

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

Use `transforms` to transform the data value to another type:

```
fields: [
  ...
  draft: [
    ecto_type: :boolean
  ]
],
data_fields: [
  ...
  draft: [
    transforms: [
      "cast(? AS integer)"
    ],
    ecto_type: :integer
  ]
]
```

See also: [Casting and data transforms](README.md#casting-and-data-transforms)

To generate custom data, add any new key with a name from the `fields` option:

```
fields: [
  ...
  genre: [
    binding: :genres,
    column: :title,
    ecto_type: :string
  ]
],
data_fields: [
  ...
  my_custom_data: [
    :genre
  ]
]
```

Custom data can also be transformed to a different type:

```
data_fields: [
  ...
  my_custom_data: [
    publish_date: [
      transforms: ["to_char(?, 'YYYY-MM-DD')"],
      ecto_type: :string
    ]
  ]
]
```

To create references to joined tables, use keys `binding` and `column`, similar to `fields`:

```
data_fields: [
  ...
  my_custom_data: [
    definition: [
      binding: :genres,
      column: :definition
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
        column: :title,
        ecto_type: :string
      ],
      publication_year: [
        ecto_type: :string
      ]
    ],
    data_fields: [
      :title,
      :author,
      my_custom_data: [
        :title,
        publication_year: [
          cast: :integer
        ],
        definition: [
          binding: :genres,
          column: :definition
        ]
      ]
    ]
  ]
]
```

## text_fields

Specifies the list of fields used for text search. The values of these fields may be optionally transformed.

The referenced fields populate the `text` column in the search view.

- Type: `list(atom())`
- Path: `sources > [source table] > text_fields`

### List entries

Either:

- A field name from option `fields`.
  - Type: `atom()`
- A keyword list:
  - Key: a field name from option `fields`
  - Values:
    - A keyword list with key `transforms`:
      - Type: `list(String.t())`

### Examples

Specifying the field names inserts their values into the `text` column.

```
sources: [
  books: [
    ...
    text_fields: [
      :author
    ]
  ]
]
```

Transform the values with the `transforms` option, where each list item is a Postgres function.
The question mark is a placeholder for the current value.

```
sources: [
  books: [
    ...
    text_fields: [
      title: [
        transforms: ["initcap(? collate \"fr_FR\")", "concat(?, ' ', length(?))"]
      ],
      author: [
        transforms: ["unaccent(?)"]
      ],
      publish_date: [
        transforms: ["to_char(?, 'YYYY-MM-DD')"]
      ]
    ]
  ]
]
```

See also: [Casting and data transforms](README.md#casting-and-data-transforms)

## facet_fields

A list of fields used to create facets, with options for labels from a database table, ranges, and hierarchies.

- Type: `list(atom()) | list(Keyword.t())`
- Path: `sources > [source table] > facet_fields`

### List entries

Either:

- A field name from option `fields`.
  - Type: `atom()`
- A keyword list:
  - Key: a field name from option `fields`
  - Values:
    - To reference a label from a database table/column:
      - Key: `label`
      - Value: a field name from option `fields`
    - To create a range of numerical entries:
      - Key: `number_range_bounds`
      - Value: a list of numbers
    - To create a range of date entries:
      - Key: `date_range_bounds`
      - Value: a list of dates, timestamps, and/or intervals
- A keyword list with key `hierarchies`:
  - Values: a keyword list
    - Key: custom name of the hierarchy
    - Values:
      - To define the hierarchy path:
        - Key: `path` (required)
        - Value: a list of field names from option `fields`
      - To reference a label from a database table/column:
        - Key: `label`
        - Value: a field name from option `fields`
      - To set a custom parent for a path:
        - Key: `parent`
        - Value: one of the listed custom hierarchy names
      - To hide facet data from a field once one of the options has been selected (by default, the facet along with the non-selected options will be returned):
        - Key: `hide_when_selected`
        - Value: boolean

### Examples

#### List of field names

By default, the field value will be returned as label.

```
sources: [
  books: [
    ...
    facet_fields: [
      :publication_year,
      :genres
    ]
  ]
]
```

#### With a label from a database table

The example adds `genre_title` as label, which is referenced from `fields`.

```
sources: [
  books: [
    joins: [
      ...
      genres: [
        on: "genres.id = book_genres.genre_id"
      ]
    ],
    fields: [
      ...
      genre_title: [
        binding: :genres,
        column: :title,
        ecto_type: :string
      ],
    ]
    facet_fields: [
      :publication_year,
      genres: [
        label: :genre_title
      ]
    ]
  ]
]
```

#### With ranges

Range buckets are categories for numerical or date values. Use a range option to define the bounds of the buckets:

- `number_range_bounds` for numerical data
- `date_range_bounds` for dates, timestamps, and intervals

Given the example list or numerical values `[1980, 2000, 2020]`, the following buckets are created:

- 0: items before 1980
- 1: items from 1980 up to (but not including) 2000
- 2: items from 2000 up to (but not including) 2020
- 3: items from 2020 onwards

Note: Lower bounds are inclusive, upper bounds are exclusive.

**Example with numerical entries**

```
sources: [
  books: [
    ...
    facet_fields: [
      publication_year: [
        number_range_bounds: [1980, 2000, 2020]
      ]
    ]
  ]
]
```

**Example with date entries**

```
sources: [
  books: [
    ...
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
  ]
]
```

See [Range labels](README.md#range-labels) for creating option labels for ranges.

#### With hierarchies

```
sources: [
  books: [
    ...
    facet_fields: [
      hierarchies: [
        level_1: [
          path: [:genres]
        ],
        level_2: [
          path: [:genres, :regions]
        ],
        level_3: [
          path: [:genres, :regions, :periods]
        ]
      ]
    ]
  ]
]
```

## sort_fields

A list of fields used to sort results. The values of these fields may be optionally transformed.

The fields referenced from the `fields` option are used to create extra columns in the search view.

- Type: `list(atom()) | list(Keyword.t())`
- Path: `sources > [source table] > sort_fields`

### List entries

Either:

- A field name from option `fields`.
  - Type: `atom()`
- A keyword list:
  - Key: a field name from option `fields`
  - Values:
    - A keyword list with key `transforms`:
      - Type: `list(String.t())`
    - A keyword list with key `ecto_type`
      - Only if the transforms result in a different type than defined in `fields`
      - The Ecto type such as `:string` or `{:array, :string}`.
      - Type: `any()`

### Examples

```
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

Transform the values with the `transforms` option, where each list item is a Postgres function.
The question mark is a placeholder for the current value.

```
sources: [
  books: [
    ...
    sort_fields: [
      :title,
      publication_year: [
        transforms: [
          "cast(? as float)"
        ],
        ecto_type: :float
      ]
    ]
  ]
]
```

See also: [Casting and data transforms](README.md#casting-and-data-transforms)

## scope

Activates scoping the table contents. See: [Scoping data](README.md#scoping-data).

## prefix

Use this when the source table is located in a database schema other than "public".

- Type: `String.t()`
- Path: `sources > [source table] > prefix`

### Example

```
sources: [
  books: [
    prefix: "catalog"
    ...
  ]
]
```

## default_order

From the Flop documentation:

> Specify a default sort order by setting the `default_order_by` and `default_order_directions` options [...].
> If no order directions are set, `:asc` is the default for all fields.

- Type: `map()`
- Path: `default_order`

### Map entries

- `order_by` A list of sort fields, where each field has a `sort_` prefix.
  - Type: `list(atom())`
- `order_directions` A list of order directions, where each element corresponds to the `order_by` element at the same index.
  - Type: `list(:asc | :desc)`

### Example

```
sources: [
  ...
],
default_order: %{
  order_by: [:sort_title],
  order_directions: [:asc]
}
```
