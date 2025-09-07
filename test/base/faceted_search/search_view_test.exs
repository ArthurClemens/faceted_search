defmodule FacetedSearch.Test.SearchViewTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
  alias FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema
  alias FacetedSearch.Test.MyApp.ScopedFacetSchema
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
                name: :source,
                binding: nil,
                field: :source_name,
                ecto_type: :string,
                table_name: :source
              },
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
                name: :summary,
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
                field: :full_name,
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
            text_fields: [:title, :summary]
          }
        ]
      }

      assert FacetedSearch.search_view_description(SimpleFacetSchema) ==
               expected
    end

    test "extended schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            data_fields: [
              %FacetedSearch.DataField{entries: nil, name: :title},
              %FacetedSearch.DataField{entries: nil, name: :author},
              %FacetedSearch.DataField{entries: nil, name: :tags},
              %FacetedSearch.DataField{entries: nil, name: :tag_titles},
              %FacetedSearch.DataField{entries: nil, name: :publish_date},
              %FacetedSearch.DataField{name: :word_count, entries: nil}
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
              },
              %FacetedSearch.FacetField{
                name: :word_count,
                parent: nil,
                path: nil,
                hierarchy: nil,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: [2000, 4000, 6000, 8000],
                range_buckets: [
                  {[:lower, 2000], 0},
                  {[2000, 4000], 1},
                  {[4000, 6000], 2},
                  {[6000, 8000], 3},
                  {[8000, :upper], 4}
                ]
              },
              %FacetedSearch.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :publish_date,
                parent: nil,
                path: nil,
                range_bounds: [
                  "now() - interval '1 year'",
                  "now() - interval '3 month'",
                  "now() - interval '1 month'",
                  "now() - interval '1 week'",
                  "now() - interval '1 day'"
                ],
                range_buckets: [
                  {[:lower, "now() - interval '1 year'"], 0},
                  {["now() - interval '1 year'", "now() - interval '3 month'"],
                   1},
                  {["now() - interval '3 month'", "now() - interval '1 month'"],
                   2},
                  {["now() - interval '1 month'", "now() - interval '1 week'"],
                   3},
                  {["now() - interval '1 week'", "now() - interval '1 day'"],
                   4},
                  {["now() - interval '1 day'", :upper], 5}
                ]
              },
              %FacetedSearch.FacetField{
                name: :category_tags_author,
                parent: :category_tags,
                path: [:tags, :author],
                hierarchy: true,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                name: :category_tags,
                parent: nil,
                path: [:tags],
                hierarchy: true,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                name: :category_author_tags,
                parent: :category_author,
                path: [:author, :tags],
                hierarchy: true,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                name: :category_author,
                parent: nil,
                path: [:author],
                hierarchy: true,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil
              }
            ],
            fields: [
              %FacetedSearch.Field{
                name: :source,
                binding: nil,
                field: :source_name,
                ecto_type: :string,
                table_name: :source
              },
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
                name: :summary,
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
                name: :word_count,
                binding: nil,
                field: nil,
                ecto_type: :integer,
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
                binding: :tag_texts,
                ecto_type: {:array, :string},
                field: :title,
                name: :tag_titles,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :authors,
                ecto_type: :string,
                field: :full_name,
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
                as: nil,
                on: "tag_texts.tag_id = tags.id",
                prefix: nil,
                table: :tag_texts
              }
            ],
            prefix: nil,
            scopes: nil,
            sort_fields: [
              %FacetedSearch.SortField{cast: nil, name: :author},
              %FacetedSearch.SortField{cast: nil, name: :publish_date}
            ],
            table_name: :articles,
            text_fields: [:author, :title, :summary]
          }
        ]
      }

      assert FacetedSearch.search_view_description(ExpandedFacetSchema) ==
               expected
    end

    test "scoped sources schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            table_name: :articles,
            scopes: [
              %FacetedSearch.Scope{
                key: :word_count,
                module: FacetedSearch.Test.MyApp.ScopedFacetSchema
              },
              %FacetedSearch.Scope{
                key: :publish_date,
                module: FacetedSearch.Test.MyApp.ScopedFacetSchema
              }
            ],
            prefix: nil,
            fields: [
              %FacetedSearch.Field{
                name: :source,
                binding: nil,
                field: :source_name,
                ecto_type: :string,
                table_name: :source
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :title,
                ecto_type: :string,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :word_count,
                ecto_type: :integer,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :publish_date,
                ecto_type: :utc_datetime,
                binding: nil,
                field: nil
              }
            ],
            joins: nil,
            data_fields: [
              %FacetedSearch.DataField{name: :title, entries: nil},
              %FacetedSearch.DataField{name: :word_count, entries: nil},
              %FacetedSearch.DataField{name: :publish_date, entries: nil}
            ],
            text_fields: nil,
            facet_fields: nil,
            sort_fields: nil
          }
        ]
      }

      assert FacetedSearch.search_view_description(ScopedFacetSchema) ==
               expected
    end

    test "multiple sources schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            table_name: :authors,
            prefix: nil,
            fields: [
              %FacetedSearch.Field{
                table_name: :source,
                name: :source,
                ecto_type: :string,
                binding: nil,
                field: :source_name
              },
              %FacetedSearch.Field{
                table_name: :authors,
                name: :author,
                ecto_type: :string,
                binding: :authors,
                field: :full_name
              },
              %FacetedSearch.Field{
                table_name: :authors,
                name: :birthdate,
                ecto_type: :date,
                binding: nil,
                field: nil
              }
            ],
            joins: nil,
            data_fields: [
              %FacetedSearch.DataField{name: :author, entries: nil},
              %FacetedSearch.DataField{name: :birthdate, entries: nil},
              %FacetedSearch.DataField{name: :source, entries: nil}
            ],
            text_fields: [:author, :birthdate, :source],
            facet_fields: [
              %FacetedSearch.FacetField{
                name: :author,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              },
              %FacetedSearch.FacetField{
                name: :source,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              }
            ],
            scopes: [
              %FacetedSearch.Scope{
                key: :source,
                module: FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema
              }
            ],
            sort_fields: [
              %FacetedSearch.SortField{name: :author, cast: nil},
              %FacetedSearch.SortField{name: :birthdate, cast: nil},
              %FacetedSearch.SortField{name: :source, cast: nil}
            ]
          },
          %FacetedSearch.Source{
            table_name: :articles,
            prefix: nil,
            fields: [
              %FacetedSearch.Field{
                name: :source,
                binding: nil,
                field: :source_name,
                ecto_type: :string,
                table_name: :source
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :title,
                ecto_type: :string,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :summary,
                ecto_type: :string,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :publish_date,
                ecto_type: :utc_datetime,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :author,
                ecto_type: :string,
                binding: :authors,
                field: :full_name
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
            data_fields: [
              %FacetedSearch.DataField{name: :author, entries: nil},
              %FacetedSearch.DataField{name: :publish_date, entries: nil},
              %FacetedSearch.DataField{name: :title, entries: nil}
            ],
            text_fields: [:title, :summary],
            facet_fields: [
              %FacetedSearch.FacetField{
                name: :author,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              },
              %FacetedSearch.FacetField{
                name: :source,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              }
            ],
            sort_fields: [
              %FacetedSearch.SortField{cast: nil, name: :publish_date},
              %FacetedSearch.SortField{cast: nil, name: :author},
              %FacetedSearch.SortField{name: :source, cast: nil}
            ],
            scopes: [
              %FacetedSearch.Scope{
                key: :source,
                module: FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema
              }
            ]
          }
        ]
      }

      assert FacetedSearch.search_view_description(MultipleSourcesFacetSchema) ==
               expected
    end
  end
end
