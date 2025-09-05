defmodule FacetedSearch.Test.NimbleSchemaTest do
  use ExUnit.Case, async: true

  alias __MODULE__.FacetSchema
  alias FacetedSearch.NimbleSchema

  describe "the validate_options/1 function" do
    test "a valid schema" do
      options = [
        sources: [
          articles: [
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
              summary: [
                ecto_type: :string
              ],
              draft: [
                ecto_type: :boolean
              ],
              publish_date: [
                ecto_type: :date
              ],
              genre: [
                binding: :genres,
                field: :title,
                ecto_type: :string
              ]
            ],
            data_fields: [
              :title,
              :draft,
              :publish_date,
              my_custom_data: [
                :title,
                draft: [
                  cast: :integer
                ],
                definition: [
                  binding: :genres,
                  field: :definition
                ]
              ]
            ],
            text_fields: [
              :title,
              :summary
            ],
            facet_fields: [
              :draft
            ]
          ]
        ]
      ]

      result = validate_options(options)
      assert Keyword.keyword?(result)
    end

    test "sources" do
      options = []

      assert_raise FacetedSearch.InvalidOptionsError,
                   "required :sources option not found, received options: [:module]",
                   fn ->
                     validate_options(options)
                   end
    end

    test "joins (unknown key)" do
      options = [
        sources: [
          articles: [
            joins: [
              book_genres: [
                xxx: "book_genres.book_id = books.id"
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "unknown options [:xxx], valid options are: [:table, :on, :prefix] (in options [:sources, :articles, :joins, :book_genres])",
                   fn ->
                     validate_options(options)
                   end
    end

    test "fields (missing ecto_type)" do
      options = [
        sources: [
          articles: [
            fields: [
              :title
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "invalid value for :fields option: expected keyword list, got: [:title] (in options [:sources, :articles])",
                   fn ->
                     validate_options(options)
                   end
    end

    test "fields (field with binding not defined in joins)" do
      options = [
        sources: [
          articles: [
            joins: [
              book_genres: [
                on: "book_genres.book_id = books.id"
              ]
            ],
            fields: [
              genre: [
                binding: :genres,
                field: :title,
                ecto_type: :string
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.fields.genre\n        The value \"genres\" for key \"binding\" is not supported because it is not listed in \"joins\".\n        Supported keys are: \"book_genres\".",
                   fn ->
                     validate_options(options)
                   end
    end

    test "data_fields (keys)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ]
            ],
            data_fields: [
              :author,
              :publish_date
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.data_fields\n        Key \"publish_date\" is not supported.\n        Expected a key that is listed in `fields`.",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "data_fields (custom data with unknown key)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ]
            ],
            data_fields: [
              :author,
              custom_data: [
                :xxx
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.data_fields.custom_data\n        Key \"xxx\" is not supported.\n        Expected a key that is listed in `fields`.",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "data_fields (custom data with unknown key in keyword list)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ],
              draft: [
                ecto_type: :boolean
              ]
            ],
            data_fields: [
              :author,
              custom_data: [
                draft: [
                  xxx: :integer
                ]
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.data_fields.custom_data\n        Key \"xxx\" is not supported.\n        Supported keys are: \"binding\", \"field\", \"cast\".",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "facet_fields (unknown key)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ]
            ],
            facet_fields: [
              :xxx
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.facet_fields\n        Key \"xxx\" is not supported.\n        Expected a key that is listed in `fields`.",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "facet_fields (unknown key for keyword list)" do
      options = [
        sources: [
          articles: [
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
            facet_fields: [
              xxx: [
                label: :genre_title
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.facet_fields\n        Key \"xxx\" is not supported.\n        Supported keys are: \"id\", \"source\", \"data\", \"text\", \"tsv\", \"genre\".",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "facet_fields (unknown key in keyword list)" do
      options = [
        sources: [
          articles: [
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
            facet_fields: [
              genre: [
                xxx: :genre_title
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.facet_fields.genre\n        Key \"xxx\" is not supported.\n        Supported keys are: \"label\", \"number_range_bounds\", \"date_range_bounds\".",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "facet_fields (invalid value in label option)" do
      options = [
        sources: [
          articles: [
            joins: [
              book_genres: [
                on: "book_genres.book_id = books.id"
              ],
              genres: [
                on: "genres.id = book_genres.genre_id"
              ]
            ],
            fields: [
              genre_title: [
                binding: :genres,
                field: :title,
                ecto_type: :string
              ]
            ],
            facet_fields: [
              genres: [
                label: :xxx
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.facet_fields\n        Key \"genres\" is not supported.\n        Supported keys are: \"id\", \"source\", \"data\", \"text\", \"tsv\", \"genre_title\".",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "facet_fields (hierarchies and duplicate keys)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ],
              publish_date: [
                ecto_type: :date
              ]
            ],
            facet_fields: [
              :author,
              hierarchies: [
                author: [
                  path: [:author]
                ],
                author_publish_date: [
                  path: [:author, :publish_date]
                ]
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   ~s(    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.facet_fields.hierarchies.author\n        Duplicate key "author".\n        The should differ from existing keys: "author", "hierarchies".),
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "facet_fields (invalid keys)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ],
              publication_year: [
                ecto_type: :integer
              ]
            ],
            facet_fields: [
              hierarchies: [
                author: [
                  path: [:author]
                ],
                author_year: [
                  path: [:author, :xxx]
                ]
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.facet_fields.hierarchies.author_year.path\n        Key \"xxx\" is not supported.\n        Expected a key that is listed in `fields`.",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "sort_fields (keys)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ]
            ],
            sort_fields: [
              :author,
              :publish_date
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.sort_fields\n        Key \"publish_date\" is not supported.\n        Expected a key that is listed in `fields`.",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "sort_fields (unknown key in keyword list)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ],
              publication_year: [
                ecto_type: :integer
              ]
            ],
            sort_fields: [
              :author,
              publication_year: [
                xxx: :float
              ]
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.sort_fields.publication_year\n        Key \"xxx\" is not supported.\n        Supported keys are: \"cast\".",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end

    test "text_fields (keys)" do
      options = [
        sources: [
          articles: [
            fields: [
              author: [
                ecto_type: :string
              ]
            ],
            text_fields: [
              :xxx
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.InvalidOptionsError,
                   "    \n    Module: Elixir.FacetedSearch.Test.NimbleSchemaTest.FacetSchema\n    Data path: sources.articles.text_fields\n        Key \"xxx\" is not supported.\n        Expected a key that is listed in `fields`.",
                   fn ->
                     NimbleSchema.validate!(
                       Keyword.put(options, :module, FacetSchema),
                       FacetSchema
                     )
                   end
    end
  end

  defp validate_options(options) do
    NimbleSchema.validate!(
      Keyword.put(options, :module, FacetSchema),
      FacetSchema
    )
  end
end

defmodule FacetedSearch.Test.NimbleSchemaTest.FacetSchema do
  @moduledoc false
end
