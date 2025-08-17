defmodule FacetedSearch.Test.SearchViewTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
  alias FacetedSearch.Test.MyApp.SimpleFacetSchema

  describe "the search_view_name/2 function" do
    test "with a regular name" do
      view_id = "articles"
      expected = "fv_articles"

      assert FacetedSearch.search_view_name(SimpleFacetSchema, view_id) ==
               expected
    end

    test "with non-alpha characters" do
      view_id = "Articles-123!"
      expected = "fv_articles_123"

      assert FacetedSearch.search_view_name(SimpleFacetSchema, view_id) ==
               expected
    end
  end

  describe "the search_view_description/1" do
    test "simple schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            data_fields: [
              %FacetedSearch.DataField{entries: nil, name: :title},
              %FacetedSearch.DataField{entries: nil, name: :publish_date},
              %FacetedSearch.DataField{name: :author, entries: nil}
            ],
            facet_fields: nil,
            fields: [
              %FacetedSearch.Field{
                binding: nil,
                ecto_type: :string,
                field: nil,
                name: :title,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                ecto_type: :string,
                field: nil,
                name: :content,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                ecto_type: :utc_datetime,
                field: nil,
                name: :publish_date,
                table_name: :articles
              },
              %FacetedSearch.Field{
                name: :author,
                binding: :authors,
                field: :name,
                ecto_type: :string,
                table_name: :articles
              }
            ],
            joins: [
              %FacetedSearch.Join{
                table: :author_articles,
                on: "author_articles.article_id = articles.id",
                as: nil,
                prefix: nil
              },
              %FacetedSearch.Join{
                table: :authors,
                on: "authors.id = author_articles.author_id",
                as: nil,
                prefix: nil
              }
            ],
            prefix: nil,
            scopes: nil,
            sort_fields: [
              %FacetedSearch.SortField{cast: nil, name: :publish_date},
              %FacetedSearch.SortField{name: :author, cast: nil}
            ],
            table_name: :articles,
            text_fields: [:title, :content]
          }
        ]
      }

      assert FacetedSearch.search_view_description(SimpleFacetSchema) ==
               expected
    end

    test "expanded schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            data_fields: [
              %FacetedSearch.DataField{name: :title, entries: nil},
              %FacetedSearch.DataField{name: :author, entries: nil},
              %FacetedSearch.DataField{name: :tags, entries: nil},
              %FacetedSearch.DataField{name: :tag_titles, entries: nil},
              %FacetedSearch.DataField{name: :publish_date, entries: nil}
            ],
            facet_fields: [
              %FacetedSearch.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :author,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: :tag_titles,
                name: :tags,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil
              }
            ],
            fields: [
              %FacetedSearch.Field{
                binding: nil,
                ecto_type: :string,
                field: nil,
                name: :title,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                ecto_type: :string,
                field: nil,
                name: :content,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                ecto_type: :utc_datetime,
                field: nil,
                name: :publish_date,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :tags,
                ecto_type: {:array, :string},
                field: :name,
                name: :tags,
                table_name: :articles
              },
              %FacetedSearch.Field{
                name: :tag_titles,
                binding: :tag_texts,
                field: :title,
                ecto_type: {:array, :string},
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :authors,
                ecto_type: :string,
                field: :name,
                name: :author,
                table_name: :articles
              }
            ],
            joins: [
              %FacetedSearch.Join{
                as: nil,
                on: "author_articles.article_id = articles.id",
                prefix: nil,
                table: :author_articles
              },
              %FacetedSearch.Join{
                as: nil,
                on: "authors.id = author_articles.author_id",
                prefix: nil,
                table: :authors
              },
              %FacetedSearch.Join{
                as: nil,
                on: "article_tags.article_id = articles.id",
                prefix: nil,
                table: :article_tags
              },
              %FacetedSearch.Join{
                as: nil,
                on: "tags.id = article_tags.tag_id",
                prefix: nil,
                table: :tags
              },
              %FacetedSearch.Join{
                table: :tag_texts,
                on: "tag_texts.tag_id = tags.id",
                prefix: nil,
                as: nil
              }
            ],
            prefix: nil,
            scopes: nil,
            sort_fields: [
              %FacetedSearch.SortField{cast: nil, name: :author},
              %FacetedSearch.SortField{cast: nil, name: :publish_date}
            ],
            table_name: :articles,
            text_fields: [:author, :title, :content]
          }
        ]
      }

      assert FacetedSearch.search_view_description(ExpandedFacetSchema) ==
               expected
    end
  end
end
