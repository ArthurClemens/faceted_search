# Schema configuration

Defines the database schema for the search view. Pass the schema configuration via the options of `use FacetedSearch`.

Create a module to contain the schema, for example `MyApp.FacetSchema`:

```
defmodule MyApp.FacetSchema do

  use FacetedSearch, [
    # configuration options
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

## sources

Settings per source. The source key refers to the name of a source table in your repo.

- Type: `list(Keyword.t())`
- Path: `sources` (schema root)
- Required

### Example

```
use FacetedSearch,
  sources: [
    books: [
       options for the books table
    ],
    movies: [
       options for the movies table
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

## data_fields

Fields to be used for filtering and data extraction in search results.
The referenced fields populate the `data` column in the search view.

Additionally, custom fields can be defined to generate data from other sources.

- Type: `list(atom()) | list(Keyword.t())`
- Path: `sources > [source table] > data_fields`

### List entries

Either:

- A field name from option `fields`.
  - Type: `atom()`
- A keyword list of field name/entry options to generate JSON data from joined tables or fields listed in the `fields` option.

Entry options are either:

- The name of a field listed in the `fields` option
  - Type: `atom()`
- A keyword list with keys:
  - `binding`
    - Name or alias of a joined table. Use togeter with option `field`.
    - If no binding is used, they entry key is used to look up the field from the `fields` option.
    - Type: `atom()`
  - `field`
    - Referenced field of the joined table.
    - Type: `atom()`
    - Required: when using `binding`
  - `cast`
    - Type to casts the value to
    - Type: `atom()`

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

To generate custom data, add any new key with a name from the `fields` option:

```
fields: [
  ...
  genre: [
    binding: :genres,
    field: :title,
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

Custom data can be cast to a different type:

```
data_fields: [
  ...
  my_custom_data: [
    publication_year: [
      cast: :integer
    ],
  ]
]
```

To create references to joined tables, use keys `binding` and `field`, similar to `fields`:

```
data_fields: [
  ...
  my_custom_data: [
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
          field: :definition
        ]
      ]
    ]
  ]
]
```

## text_fields

A list of fields used for text search.

The referenced fields populate the `text` column in the search view.

- Type: `list(atom())`
- Path: `sources > [source table] > text_fields`

### List entries

- A field name from option `fields`.
  - Type: `atom()`

### Examples

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

## facet_fields

A list of fields used to create facets, with options for labels from a database table, and ranges.

The referenced fields populate the `tsv` column in the search view. 

- Type: `list(atom()) | list(Keyword.t())`
- Path: `sources > [source table] > facet_fields`

### List entries

Either:

- A field name from option `fields`.
- A keyword list:
  - Key: a field name from option `fields`
  - Value (either or both):
    - To reference a label from a database table/column:
      - Key: `label` 
      - Value: a field name from option `fields`
    - To create a range of numerical entries:
      - Key: `number_range_bounds`
      - Value: a list of numbers
    - To create a range of date entries:
      - Key: `date_range_bounds`
      - Value: a list of dates, timestamps, and/or intervals


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
        field: :title,
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

-  `number_range_bounds` - for numerical data
-  `date_range_bounds` - for dates, timestamps, and intervals

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

## sort_fields

A list of fields used for sorting results. Field values can optionally be cast to another data type.

The fields referenced from the `fields` option are used to create extra columns in the search view. 

- Type: `list(atom()) | list(Keyword.t())`
- Path: `sources > [source table] > sort_fields`

### List entries

Either:

- A field name from option `fields`.
  - Type: `atom()`
- A keyword list containing key `cast` to cast the orginal value to a sort value - see examples below.
  - Type: `{atom(), Keyword.t()}`

### Examples

#### Without casting

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

#### With casting

```
sources: [
  books: [
    ...
    sort_fields: [
      :title,
      publication_year: [
        cast: :float
      ]
    ]
  ]
]
```

## scopes

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
