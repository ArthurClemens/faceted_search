defmodule FacetedSearch.Test.SearchViewTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
  alias FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema
  alias FacetedSearch.Test.MyApp.PrefixFacetSchema
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

    test "prefix schema" do
      view_id = "articles"
      expected = "fv_articles"

      assert FacetedSearch.search_view_name(PrefixFacetSchema, view_id) ==
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
              %FacetedSearch.DataField{entries: nil, name: :author}
            ],
            facet_fields: nil,
            fields: [
              %FacetedSearch.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
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
              }
            ],
            prefix: nil,
            scopes: nil,
            sort_fields: [
              %FacetedSearch.SortField{cast: nil, name: :publish_date},
              %FacetedSearch.SortField{cast: nil, name: :author}
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
              %FacetedSearch.DataField{
                entries: [
                  %FacetedSearch.DataFieldEntry{
                    name: :word_count,
                    binding: nil,
                    column: nil,
                    field_name: :word_count,
                    cast: :text
                  },
                  %FacetedSearch.DataFieldEntry{
                    name: :type,
                    binding: :tags,
                    column: :name,
                    field_name: nil,
                    cast: nil
                  }
                ],
                name: :indicators
              }
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
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :word_count,
                parent: nil,
                path: nil,
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
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_tags_author,
                parent: :category_tags,
                path: [:tags, :author],
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_tags,
                parent: nil,
                path: [:tags],
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_author_tags,
                parent: :category_author,
                path: [:author, :tags],
                range_bounds: nil,
                range_buckets: nil
              },
              %FacetedSearch.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_author,
                parent: nil,
                path: [:author],
                range_bounds: nil,
                range_buckets: nil
              }
            ],
            fields: [
              %FacetedSearch.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :word_count,
                ecto_type: :integer,
                name: :word_count,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :tags,
                column: :name,
                ecto_type: {:array, :string},
                name: :tags,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :tag_texts,
                column: :title,
                ecto_type: {:array, :string},
                name: :tag_titles,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
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
            data_fields: [
              %FacetedSearch.DataField{entries: nil, name: :title},
              %FacetedSearch.DataField{entries: nil, name: :word_count},
              %FacetedSearch.DataField{entries: nil, name: :publish_date}
            ],
            facet_fields: nil,
            fields: [
              %FacetedSearch.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :word_count,
                ecto_type: :integer,
                name: :word_count,
                prefix: nil,
                table_name: :articles
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              }
            ],
            joins: nil,
            prefix: nil,
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
            sort_fields: nil,
            table_name: :articles,
            text_fields: nil
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
            data_fields: [
              %FacetedSearch.DataField{entries: nil, name: :author},
              %FacetedSearch.DataField{entries: nil, name: :birthdate},
              %FacetedSearch.DataField{entries: nil, name: :source}
            ],
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
            fields: [
              %FacetedSearch.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %FacetedSearch.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :authors
              },
              %FacetedSearch.Field{
                binding: nil,
                column: :birthdate,
                ecto_type: :date,
                name: :birthdate,
                prefix: nil,
                table_name: :authors
              }
            ],
            joins: nil,
            prefix: nil,
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
            ],
            table_name: :authors,
            text_fields: [:author, :birthdate, :source]
          },
          %FacetedSearch.Source{
            prefix: nil,
            fields: [
              %FacetedSearch.Field{
                table_name: :source,
                prefix: nil,
                name: :source,
                ecto_type: :string,
                binding: nil,
                column: :source_name
              },
              %FacetedSearch.Field{
                table_name: :articles,
                prefix: nil,
                name: :title,
                ecto_type: :string,
                binding: nil,
                column: :title
              },
              %FacetedSearch.Field{
                table_name: :articles,
                prefix: nil,
                name: :summary,
                ecto_type: :string,
                binding: nil,
                column: :summary
              },
              %FacetedSearch.Field{
                table_name: :articles,
                prefix: nil,
                name: :publish_date,
                ecto_type: :utc_datetime,
                binding: nil,
                column: :publish_date
              },
              %FacetedSearch.Field{
                table_name: :articles,
                prefix: nil,
                name: :author,
                ecto_type: :string,
                binding: :authors,
                column: :full_name
              }
            ],
            data_fields: [
              %FacetedSearch.DataField{name: :author, entries: nil},
              %FacetedSearch.DataField{name: :publish_date, entries: nil},
              %FacetedSearch.DataField{name: :title, entries: nil}
            ],
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
            table_name: :articles,
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
            scopes: [
              %FacetedSearch.Scope{
                key: :source,
                module: FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema
              }
            ],
            sort_fields: [
              %FacetedSearch.SortField{name: :publish_date, cast: nil},
              %FacetedSearch.SortField{name: :author, cast: nil},
              %FacetedSearch.SortField{name: :source, cast: nil}
            ],
            text_fields: [:title, :summary]
          }
        ]
      }

      assert FacetedSearch.search_view_description(MultipleSourcesFacetSchema) ==
               expected
    end

    test "prefix schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            table_name: :categories,
            scopes: nil,
            prefix: "classifications",
            fields: [
              %FacetedSearch.Field{
                table_name: :source,
                prefix: nil,
                name: :source,
                ecto_type: :string,
                binding: nil,
                column: :source_name
              },
              %FacetedSearch.Field{
                table_name: :categories,
                prefix: "classifications",
                name: :category_name,
                ecto_type: :string,
                binding: nil,
                column: :name
              },
              %FacetedSearch.Field{
                table_name: :categories,
                prefix: "classifications",
                name: :article_title,
                ecto_type: :string,
                binding: :articles,
                column: :title
              }
            ],
            joins: [
              %FacetedSearch.Join{
                table: :article_categories,
                on: "article_categories.category_id = categories.id",
                as: nil,
                prefix: "public"
              },
              %FacetedSearch.Join{
                table: :articles,
                on: "articles.id = article_categories.article_id",
                as: nil,
                prefix: "public"
              }
            ],
            data_fields: [
              %FacetedSearch.DataField{name: :article_title, entries: nil},
              %FacetedSearch.DataField{name: :category_name, entries: nil}
            ],
            text_fields: [:article_title, :category_name],
            facet_fields: nil,
            sort_fields: [
              %FacetedSearch.SortField{name: :article_title, cast: nil},
              %FacetedSearch.SortField{name: :category_name, cast: nil}
            ]
          }
        ]
      }

      assert FacetedSearch.search_view_description(PrefixFacetSchema) ==
               expected
    end
  end
end
