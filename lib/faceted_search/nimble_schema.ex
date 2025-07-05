defmodule FacetedSearch.NimbleSchema do
  @moduledoc false

  alias FacetedSearch.Errors.InvalidOptionsError
  alias FacetedSearch.Errors.MissingCallbackError

  @join_option_entries_schema [
    table: [
      type: :atom,
      required: true,
      doc: "Table name."
    ],
    as: [
      type: :atom,
      doc: "Table alias."
    ],
    on: [
      type: :string,
      required: true,
      doc: "Joins the table using an ON clause."
    ],
    prefix: [
      type: :string,
      doc: "Database schema other than 'public'."
    ]
  ]

  @raw_faceted_search_option_schema [
    module: [
      type: :atom,
      doc: "The schema module that calls `use FacetedSearch`. This is inserted automatically."
    ],
    sources: [
      type: :keyword_list,
      required: true,
      keys: [
        *: [
          type: :keyword_list,
          keys: [
            prefix: [
              type: :string,
              doc: """
              Use when the source table is located in a different database schema.

              ### prefix example

              ```
              sources: [
                books: [
                  prefix: "catalog"
                  ...
                ]
              ]
              ```
              """
            ],
            joins: [
              type: {:list, {:keyword_list, @join_option_entries_schema}},
              doc:
                """
                Creates JOIN statements to collect data from other tables. The `table` name (or the `as` alias)
                can be used in option `fields` using `binding` to extract values.
                """ <>
                  NimbleOptions.docs(@join_option_entries_schema, nest_level: 1) <>
                  """
                  ### joins examples

                  ```
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
                      ...
                    ]
                  ]
                  ```
                  """
            ],
            fields: [
              type: :keyword_list,
              keys: [
                *: [
                  type: :keyword_list,
                  keys: [
                    binding: [type: :atom, doc: "Name or alias of a joined table."],
                    field: [type: :atom, doc: "Referenced field of the joined table."],
                    ecto_type: [
                      type: :any,
                      required: true,
                      doc: """
                      Identical to the Flop option.

                      From the Flop documentation:
                      > The Ecto type of the field. The filter operator and value validation is based on this option.
                      """
                    ],
                    filter: [
                      type: {:tuple, [:atom, :atom, :keyword_list]},
                      doc: """
                      Identical to the Flop option, except that a default filter is applied by FacetSearch, making this option optional. If set, this option overrides the default filter.

                      From the Flop documentation:
                      > A module/function/options tuple referencing a custom filter function. The function must take the Ecto query, the Flop.Filter struct, and the options from the tuple as arguments.
                      """
                    ],
                    operators: [
                      type: {:list, :atom},
                      doc: """
                      Identical to the Flop option.

                      From the Flop documentation:
                      > Defines which filter operators are allowed for this field. If omitted, all operators will be accepted.
                      """
                    ]
                  ]
                ]
              ],
              doc: """
              A list of field names used to provide structured data.

              ### fields examples

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

              With `binding` to get data from joined tables:

              ```
              sources: [
                books: [
                  ... # joins
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
              """
            ],
            data_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}},
              doc: """
              A list of field names used for filtering.
              Either pass the field name atom (which must be listed under `fields`), or a keyword list to
              generate a list of JSON objects.


              ### data_fields examples

              ```
              data_fields: [
                :title,
                :author
              ]
              ```

              JSON object definitions are listed under the `entries` key, followed by a list of keys-value items, similar to `fields`.

              ```
              data_fields: [
                :title,
                :author,
                genres: [
                  entries: [
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
              ```
              """
            ],
            text_fields: [
              type: {:list, :atom},
              doc: """
              A list of field names used for text search. Entries must be listed under `fields`.

              ### text_fields examples

              ```
              text_fields: [
                :author
              ]
              ```
              """
            ],
            facet_fields: [
              type: {:list, :atom},
              doc: """
              A list of field names used to create facets. Entries must be listed under `fields`.

              ### facet_fields examples

              ```
              facet_fields: [
                :publication_year,
                :genres
              ]
              ```
              """
            ],
            sort_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}},
              doc: """
              A list of fields used to for sorting. Entries must be listed under `fields`.
              Either pass the field name atom, or a keyword list with key `cast` to cast the orginal value to a sort value.

              ### sort_fields examples

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
              """
            ],
            scopes: [
              type: {:list, :atom},
              doc: """
              Activates scoping the table contents. See: [Scoping data](README.md#scoping-data).
              """
            ]
          ]
        ]
      ],
      doc: """
      Settings per source. The source key is the name of a source table in your repo.
      """
    ]
  ]

  @option_schema NimbleOptions.new!(@raw_faceted_search_option_schema)

  def option_schema, do: @option_schema

  def validate!(opts, module) do
    validate!(opts, option_schema(), module)
  end

  def validate!(opts, %NimbleOptions{} = schema, module) do
    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        validate_scope_callback(opts, opts[:module])

        opts

      {:error, err} ->
        raise InvalidOptionsError.from_nimble(err,
                module: module
              )
    end
  end

  defp validate_scope_callback(opts, module) do
    has_scopes_option =
      Keyword.get_values(opts, :sources)
      |> List.flatten()
      |> Enum.map(fn {_, sublist} ->
        Keyword.has_key?(sublist, :scopes) and Keyword.get(sublist, :scopes) != []
      end)
      |> List.flatten()
      |> Enum.any?()

    require_scope_by_callback(module, has_scopes_option)
  end

  defp require_scope_by_callback(module, has_scopes_option) when has_scopes_option do
    if not Module.defines?(module, {:scope_by, 2}) do
      raise MissingCallbackError.message(%{
              callback: "scope_by/2",
              module: module
            })
    end
  end

  defp require_scope_by_callback(_module, _has_scopes_option), do: nil
end
