defmodule FacetedSearch.Test.SchemaTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
  alias FacetedSearch.Test.MyApp.SimpleFacetSchema

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
               {:content, [ecto_type: :string]},
               {:publish_date, [ecto_type: :utc_datetime]},
               {:author, [binding: :authors, field: :name, ecto_type: :string]}
             ]},
            data_fields: [:title, :publish_date, :author],
            text_fields: [:title, :content],
            sort_fields: [:publish_date, :author]
          ]
        ]
      ]

      assert FacetedSearch.options(SimpleFacetSchema) == expected
    end

    test "expanded schema" do
      expected = [
        module: ExpandedFacetSchema,
        sources: [
          articles: [
            joins: [
              author_articles: [on: "author_articles.article_id = articles.id"],
              authors: [on: "authors.id = author_articles.author_id"]
            ],
            fields: [
              {:title, [ecto_type: :string]},
              {:content, [ecto_type: :string]},
              {:publish_date, [ecto_type: :utc_datetime]},
              {:author, [binding: :authors, field: :name, ecto_type: :string]}
            ],
            data_fields: [:author, :title, :publish_date],
            text_fields: [:author, :title, :content],
            sort_fields: [:author, :publish_date],
            facet_fields: [:author]
          ]
        ]
      ]

      assert FacetedSearch.options(ExpandedFacetSchema) == expected
    end
  end

  test "ecto_schema/2 returns the Ecto schema for the search view" do
    view_id = "articles"
    expected = {"fv_articles", SimpleFacetSchema}
    assert FacetedSearch.ecto_schema(SimpleFacetSchema, view_id) == expected
  end
end
