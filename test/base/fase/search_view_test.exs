defmodule Fase.Test.SearchViewTest do
  use ExUnit.Case, async: true

  alias Fase.Test.MyApp.ExpandedFacetSchema
  alias Fase.Test.MyApp.MultipleSourcesFacetSchema
  alias Fase.Test.MyApp.PrefixFacetSchema
  alias Fase.Test.MyApp.ScopedFacetSchema
  alias Fase.Test.MyApp.SimpleFacetSchema

  describe "the search_view_name/2 function" do
    test "with a regular name" do
      view_id = "articles"
      expected = "fv_articles"

      assert Fase.search_view_name(SimpleFacetSchema, view_id) ==
               expected
    end

    test "with non-alpha characters" do
      view_id = "Articles-123!"
      expected = "fv_articles_123"

      assert Fase.search_view_name(SimpleFacetSchema, view_id) ==
               expected
    end

    test "prefix schema" do
      view_id = "articles"
      expected = "fv_articles"

      assert Fase.search_view_name(PrefixFacetSchema, view_id) ==
               expected
    end
  end

  describe "the search_view_description/1" do
    test "simple schema" do
      expected = %Fase.SearchViewDescription{
        sources: [
          %Fase.Source{
            data_fields: [
              %Fase.DataField{entries: nil, name: :title},
              %Fase.DataField{entries: nil, name: :publish_date},
              %Fase.DataField{entries: nil, name: :author}
            ],
            facet_fields: nil,
            fields: [
              %Fase.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :articles
              }
            ],
            joins: [
              %Fase.Join{
                as: nil,
                on: "author_articles.article_id = articles.id",
                prefix: nil,
                table: :author_articles
              },
              %Fase.Join{
                as: nil,
                on: "authors.id = author_articles.author_id",
                prefix: nil,
                table: :authors
              }
            ],
            prefix: nil,
            scopes: nil,
            sort_fields: [
              %Fase.SortField{cast: nil, name: :publish_date},
              %Fase.SortField{cast: nil, name: :author}
            ],
            table_name: :articles,
            text_fields: [:title, :summary]
          }
        ]
      }

      assert Fase.search_view_description(SimpleFacetSchema) ==
               expected
    end

    test "extended schema" do
      expected = %Fase.SearchViewDescription{
        id: %{ecto_type: :binary_id},
        sources: [
          %Fase.Source{
            data_fields: [
              %Fase.DataField{entries: nil, name: :title},
              %Fase.DataField{entries: nil, name: :author},
              %Fase.DataField{entries: nil, name: :tags},
              %Fase.DataField{entries: nil, name: :tag_titles},
              %Fase.DataField{entries: nil, name: :publish_date},
              %Fase.DataField{
                entries: [
                  %Fase.DataFieldEntry{
                    name: :word_count,
                    binding: nil,
                    column: nil,
                    field_name: :word_count,
                    cast: :text
                  },
                  %Fase.DataFieldEntry{
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
              %Fase.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :author,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: :tag_titles,
                name: :tags,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.FacetField{
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
              %Fase.FacetField{
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
              %Fase.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_tags_author,
                parent: :category_tags,
                path: [:tags, :author],
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_tags,
                parent: nil,
                path: [:tags],
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_author_tags,
                parent: :category_author,
                path: [:author, :tags],
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.FacetField{
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
              %Fase.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: nil,
                column: :word_count,
                ecto_type: :integer,
                name: :word_count,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: :tags,
                column: :name,
                ecto_type: {:array, :string},
                name: :tags,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: :tag_texts,
                column: :title,
                ecto_type: {:array, :string},
                name: :tag_titles,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :articles
              }
            ],
            joins: [
              %Fase.Join{
                as: nil,
                on: "author_articles.article_id = articles.id",
                prefix: nil,
                table: :author_articles
              },
              %Fase.Join{
                as: nil,
                on: "authors.id = author_articles.author_id",
                prefix: nil,
                table: :authors
              },
              %Fase.Join{
                as: nil,
                on: "article_tags.article_id = articles.id",
                prefix: nil,
                table: :article_tags
              },
              %Fase.Join{
                as: nil,
                on: "tags.id = article_tags.tag_id",
                prefix: nil,
                table: :tags
              },
              %Fase.Join{
                as: nil,
                on: "tag_texts.tag_id = tags.id",
                prefix: nil,
                table: :tag_texts
              }
            ],
            prefix: nil,
            scopes: nil,
            sort_fields: [
              %Fase.SortField{cast: nil, name: :author},
              %Fase.SortField{cast: nil, name: :publish_date}
            ],
            table_name: :articles,
            text_fields: [:author, :title, :summary]
          }
        ]
      }

      assert Fase.search_view_description(ExpandedFacetSchema) ==
               expected
    end

    test "scoped sources schema" do
      expected = %Fase.SearchViewDescription{
        sources: [
          %Fase.Source{
            data_fields: [
              %Fase.DataField{entries: nil, name: :title},
              %Fase.DataField{entries: nil, name: :word_count},
              %Fase.DataField{entries: nil, name: :publish_date}
            ],
            facet_fields: nil,
            fields: [
              %Fase.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
                binding: nil,
                column: :word_count,
                ecto_type: :integer,
                name: :word_count,
                prefix: nil,
                table_name: :articles
              },
              %Fase.Field{
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
              %Fase.Scope{
                key: :word_count,
                module: Fase.Test.MyApp.ScopedFacetSchema
              },
              %Fase.Scope{
                key: :publish_date,
                module: Fase.Test.MyApp.ScopedFacetSchema
              }
            ],
            sort_fields: nil,
            table_name: :articles,
            text_fields: nil
          }
        ]
      }

      assert Fase.search_view_description(ScopedFacetSchema) ==
               expected
    end

    test "multiple sources schema" do
      expected = %Fase.SearchViewDescription{
        sources: [
          %Fase.Source{
            data_fields: [
              %Fase.DataField{entries: nil, name: :author},
              %Fase.DataField{entries: nil, name: :birthdate},
              %Fase.DataField{entries: nil, name: :source}
            ],
            facet_fields: [
              %Fase.FacetField{
                name: :author,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              },
              %Fase.FacetField{
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
              %Fase.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :authors
              },
              %Fase.Field{
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
              %Fase.Scope{
                key: :source,
                module: Fase.Test.MyApp.MultipleSourcesFacetSchema
              }
            ],
            sort_fields: [
              %Fase.SortField{name: :author, cast: nil},
              %Fase.SortField{name: :birthdate, cast: nil},
              %Fase.SortField{name: :source, cast: nil}
            ],
            table_name: :authors,
            text_fields: [:author, :birthdate, :source]
          },
          %Fase.Source{
            prefix: nil,
            fields: [
              %Fase.Field{
                table_name: :source,
                prefix: nil,
                name: :source,
                ecto_type: :string,
                binding: nil,
                column: :source_name
              },
              %Fase.Field{
                table_name: :articles,
                prefix: nil,
                name: :title,
                ecto_type: :string,
                binding: nil,
                column: :title
              },
              %Fase.Field{
                table_name: :articles,
                prefix: nil,
                name: :summary,
                ecto_type: :string,
                binding: nil,
                column: :summary
              },
              %Fase.Field{
                table_name: :articles,
                prefix: nil,
                name: :publish_date,
                ecto_type: :utc_datetime,
                binding: nil,
                column: :publish_date
              },
              %Fase.Field{
                table_name: :articles,
                prefix: nil,
                name: :author,
                ecto_type: :string,
                binding: :authors,
                column: :full_name
              }
            ],
            data_fields: [
              %Fase.DataField{name: :author, entries: nil},
              %Fase.DataField{name: :publish_date, entries: nil},
              %Fase.DataField{name: :title, entries: nil}
            ],
            facet_fields: [
              %Fase.FacetField{
                name: :author,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              },
              %Fase.FacetField{
                name: :source,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              },
              %Fase.FacetField{
                name: :publish_date,
                parent: nil,
                path: nil,
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
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
              }
            ],
            table_name: :articles,
            joins: [
              %Fase.Join{
                table: :author_articles,
                on: "author_articles.article_id = articles.id",
                as: nil,
                prefix: nil
              },
              %Fase.Join{
                table: :authors,
                on: "authors.id = author_articles.author_id",
                as: nil,
                prefix: nil
              }
            ],
            scopes: [
              %Fase.Scope{
                key: :source,
                module: Fase.Test.MyApp.MultipleSourcesFacetSchema
              }
            ],
            sort_fields: [
              %Fase.SortField{name: :publish_date, cast: nil},
              %Fase.SortField{name: :author, cast: nil},
              %Fase.SortField{name: :source, cast: nil}
            ],
            text_fields: [:title, :summary]
          }
        ]
      }

      assert Fase.search_view_description(MultipleSourcesFacetSchema) ==
               expected
    end

    test "prefix schema" do
      expected = %Fase.SearchViewDescription{
        sources: [
          %Fase.Source{
            table_name: :categories,
            scopes: nil,
            prefix: "classifications",
            fields: [
              %Fase.Field{
                table_name: :source,
                prefix: nil,
                name: :source,
                ecto_type: :string,
                binding: nil,
                column: :source_name
              },
              %Fase.Field{
                table_name: :categories,
                prefix: "classifications",
                name: :category_name,
                ecto_type: :string,
                binding: nil,
                column: :name
              },
              %Fase.Field{
                table_name: :categories,
                prefix: "classifications",
                name: :article_title,
                ecto_type: :string,
                binding: :articles,
                column: :title
              }
            ],
            joins: [
              %Fase.Join{
                table: :article_categories,
                on: "article_categories.category_id = categories.id",
                as: nil,
                prefix: "public"
              },
              %Fase.Join{
                table: :articles,
                on: "articles.id = article_categories.article_id",
                as: nil,
                prefix: "public"
              }
            ],
            data_fields: [
              %Fase.DataField{name: :article_title, entries: nil},
              %Fase.DataField{name: :category_name, entries: nil}
            ],
            text_fields: [:article_title, :category_name],
            facet_fields: nil,
            sort_fields: [
              %Fase.SortField{name: :article_title, cast: nil},
              %Fase.SortField{name: :category_name, cast: nil}
            ]
          }
        ]
      }

      assert Fase.search_view_description(PrefixFacetSchema) ==
               expected
    end
  end
end
