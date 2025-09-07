defmodule Fase.Test.SchemaTest do
  use ExUnit.Case, async: true

  alias Fase.Test.MyApp.ExpandedFacetSchema
  alias Fase.Test.MyApp.MultipleSourcesFacetSchema
  alias Fase.Test.MyApp.PrefixFacetSchema
  alias Fase.Test.MyApp.ScopedFacetSchema
  alias Fase.Test.MyApp.SimpleFacetSchema

  describe "the options/1 function" do
    test "simple schema" do
      expected = [
        module: SimpleFacetSchema,
        sources: [
          articles: [
            {:joins,
             [
               author_articles: [on: "author_articles.article_id = articles.id"],
               authors: [on: "authors.id = author_articles.author_id"]
             ]},
            {:fields,
             [
               {:title, [ecto_type: :string]},
               {:summary, [ecto_type: :string]},
               {:publish_date, [ecto_type: :utc_datetime]},
               {:author,
                [binding: :authors, column: :full_name, ecto_type: :string]}
             ]},
            data_fields: [:title, :publish_date, :author],
            text_fields: [:title, :summary],
            sort_fields: [:publish_date, :author]
          ]
        ]
      ]

      assert Fase.options(SimpleFacetSchema) == expected
    end

    test "extended schema" do
      expected = [
        module: ExpandedFacetSchema,
        id: [ecto_type: :binary_id],
        sources: [
          articles: [
            joins: [
              author_articles: [on: "author_articles.article_id = articles.id"],
              authors: [on: "authors.id = author_articles.author_id"],
              article_tags: [on: "article_tags.article_id = articles.id"],
              tags: [on: "tags.id = article_tags.tag_id"],
              tag_texts: [on: "tag_texts.tag_id = tags.id"]
            ],
            fields: [
              {:title, [ecto_type: :string]},
              {:summary, [ecto_type: :string]},
              {:publish_date, [ecto_type: :utc_datetime]},
              {:word_count, [ecto_type: :integer]},
              {:tags,
               [binding: :tags, column: :name, ecto_type: {:array, :string}]},
              {:tag_titles,
               [
                 binding: :tag_texts,
                 column: :title,
                 ecto_type: {:array, :string}
               ]},
              {:author,
               [binding: :authors, column: :full_name, ecto_type: :string]}
            ],
            data_fields: [
              :title,
              :author,
              :tags,
              :tag_titles,
              :publish_date,
              {:indicators,
               [
                 word_count: [cast: :text],
                 type: [binding: :tags, column: :name]
               ]}
            ],
            text_fields: [:author, :title, :summary],
            sort_fields: [:author, :publish_date],
            facet_fields: [
              :author,
              {:tags, [label: :tag_titles]},
              {:word_count, [number_range_bounds: [2000, 4000, 6000, 8000]]},
              {:publish_date,
               [
                 date_range_bounds: [
                   "now() - interval '1 year'",
                   "now() - interval '3 month'",
                   "now() - interval '1 month'",
                   "now() - interval '1 week'",
                   "now() - interval '1 day'"
                 ]
               ]},
              {:hierarchies,
               [
                 category_author: [path: [:author]],
                 category_author_tags: [path: [:author, :tags]],
                 category_tags: [path: [:tags]],
                 category_tags_author: [path: [:tags, :author]]
               ]}
            ]
          ]
        ]
      ]

      assert Fase.options(ExpandedFacetSchema) == expected
    end

    test "scoped schema" do
      expected = [
        {:module, Fase.Test.MyApp.ScopedFacetSchema},
        {:sources,
         [
           articles: [
             scope_keys: [:word_count, :publish_date],
             fields: [
               title: [ecto_type: :string],
               word_count: [ecto_type: :integer],
               publish_date: [ecto_type: :utc_datetime]
             ],
             data_fields: [:title, :word_count, :publish_date]
           ]
         ]}
      ]

      assert Fase.options(ScopedFacetSchema) == expected
    end

    test "multiple sources schema" do
      expected = [
        module: Fase.Test.MyApp.MultipleSourcesFacetSchema,
        sources: [
          authors: [
            {:scope_keys, [:source]},
            fields: [
              author: [
                binding: :authors,
                column: :full_name,
                ecto_type: :string
              ],
              birthdate: [ecto_type: :date]
            ],
            data_fields: [:author, :birthdate, :source],
            text_fields: [:author, :birthdate, :source],
            sort_fields: [:author, :birthdate, :source],
            facet_fields: [:author, :source]
          ],
          articles: [
            {:scope_keys, [:source]},
            joins: [
              author_articles: [on: "author_articles.article_id = articles.id"],
              authors: [on: "authors.id = author_articles.author_id"]
            ],
            fields: [
              title: [ecto_type: :string],
              summary: [ecto_type: :string],
              publish_date: [ecto_type: :utc_datetime],
              author: [
                binding: :authors,
                column: :full_name,
                ecto_type: :string
              ]
            ],
            data_fields: [:author, :publish_date, :title],
            text_fields: [:title, :summary],
            sort_fields: [:publish_date, :author, :source],
            facet_fields: [
              :author,
              :source,
              {:publish_date,
               [
                 date_range_bounds: [
                   "now() - interval '1 year'",
                   "now() - interval '3 month'",
                   "now() - interval '1 month'",
                   "now() - interval '1 week'",
                   "now() - interval '1 day'"
                 ]
               ]}
            ]
          ]
        ]
      ]

      assert Fase.options(MultipleSourcesFacetSchema) == expected
    end

    test "prefix schema" do
      expected = [
        {:module, Fase.Test.MyApp.PrefixFacetSchema},
        {:sources,
         [
           categories: [
             prefix: "classifications",
             joins: [
               article_categories: [
                 prefix: "public",
                 on: "article_categories.category_id = categories.id"
               ],
               articles: [
                 prefix: "public",
                 on: "articles.id = article_categories.article_id"
               ]
             ],
             fields: [
               category_name: [column: :name, ecto_type: :string],
               article_title: [
                 binding: :articles,
                 column: :title,
                 ecto_type: :string
               ]
             ],
             data_fields: [:article_title, :category_name],
             text_fields: [:article_title, :category_name],
             sort_fields: [:article_title, :category_name]
           ]
         ]}
      ]

      assert Fase.options(PrefixFacetSchema) == expected
    end
  end

  test "ecto_schema/2 returns the Ecto schema for the search view" do
    view_id = "articles"
    expected = {"fv_articles", SimpleFacetSchema}
    assert Fase.ecto_schema(SimpleFacetSchema, view_id) == expected
  end
end
