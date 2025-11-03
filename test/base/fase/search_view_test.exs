defmodule Fase.Test.SearchViewTest do
  use ExUnit.Case, async: true

  alias Fase.Test.MyApp.ExtendedFacetSchema
  alias Fase.Test.MyApp.MultipleSourcesFacetSchema
  alias Fase.Test.MyApp.PrefixFacetSchema
  alias Fase.Test.MyApp.ScopedFacetSchema
  alias Fase.Test.MyApp.SimpleFacetSchema
  alias Fase.Test.MyApp.TimestampsFacetSchema

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
      expected = %Fase.SearchView.SearchViewDescription{
        sources: [
          %Fase.SearchView.Source{
            data_fields: [
              %Fase.SearchView.DataField{entries: nil, name: :title},
              %Fase.SearchView.DataField{entries: nil, name: :publish_date},
              %Fase.SearchView.DataField{entries: nil, name: :author}
            ],
            facet_fields: nil,
            fields: [
              %Fase.SearchView.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :articles
              }
            ],
            joins: [
              %Fase.SearchView.Join{
                as: nil,
                on: "author_articles.article_id = articles.id",
                prefix: nil,
                table: :author_articles
              },
              %Fase.SearchView.Join{
                as: nil,
                on: "authors.id = author_articles.author_id",
                prefix: nil,
                table: :authors
              }
            ],
            prefix: nil,
            scope: nil,
            sort_fields: [
              %Fase.SearchView.SortField{transforms: nil, name: :publish_date},
              %Fase.SearchView.SortField{transforms: nil, name: :author}
            ],
            table_name: :articles,
            text_fields: [
              %Fase.SearchView.TextField{name: :title, transforms: nil},
              %Fase.SearchView.TextField{name: :summary, transforms: nil}
            ]
          }
        ]
      }

      assert Fase.search_view_description(SimpleFacetSchema) ==
               expected
    end

    test "extended schema" do
      expected = %Fase.SearchView.SearchViewDescription{
        id: nil,
        sources: [
          %Fase.SearchView.Source{
            data_fields: [
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :id,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :title,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :author,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :tags,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :tag_titles,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: :integer,
                entries: nil,
                name: :draft,
                transforms: ["cast(? as integer)"]
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: [
                  %Fase.SearchView.CustomDataFieldEntry{
                    name: :draft,
                    binding: nil,
                    column: nil,
                    transforms: nil,
                    ecto_type: nil,
                    field_name: :draft
                  },
                  %Fase.SearchView.CustomDataFieldEntry{
                    binding: nil,
                    column: nil,
                    ecto_type: :string,
                    field_name: :word_count,
                    name: :word_count,
                    transforms: ["cast(? as text)"]
                  },
                  %Fase.SearchView.CustomDataFieldEntry{
                    binding: :tags,
                    column: :name,
                    ecto_type: nil,
                    field_name: nil,
                    name: :type,
                    transforms: nil
                  }
                ],
                name: :indicators,
                transforms: nil
              }
            ],
            facet_fields: [
              %Fase.SearchView.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :author,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.SearchView.FacetField{
                hide_when_selected: false,
                hierarchy: nil,
                label_field: :tag_titles,
                name: :tags,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.SearchView.FacetField{
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
              %Fase.SearchView.FacetField{
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
              %Fase.SearchView.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_tags_author,
                parent: :category_tags,
                path: [:tags, :author],
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.SearchView.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_tags,
                parent: nil,
                path: [:tags],
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.SearchView.FacetField{
                hide_when_selected: false,
                hierarchy: true,
                label_field: nil,
                name: :category_author_tags,
                parent: :category_author,
                path: [:author, :tags],
                range_bounds: nil,
                range_buckets: nil
              },
              %Fase.SearchView.FacetField{
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
              %Fase.SearchView.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :id,
                ecto_type: :uuid,
                name: :id,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :draft,
                ecto_type: :boolean,
                name: :draft,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :word_count,
                ecto_type: :integer,
                name: :word_count,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: :tags,
                column: :name,
                ecto_type: {:array, :string},
                name: :tags,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: :tag_texts,
                column: :title,
                ecto_type: {:array, :string},
                name: :tag_titles,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :articles
              }
            ],
            joins: [
              %Fase.SearchView.Join{
                as: nil,
                on: "author_articles.article_id = articles.id",
                prefix: nil,
                table: :author_articles
              },
              %Fase.SearchView.Join{
                as: nil,
                on: "authors.id = author_articles.author_id",
                prefix: nil,
                table: :authors
              },
              %Fase.SearchView.Join{
                as: nil,
                on: "article_tags.article_id = articles.id",
                prefix: nil,
                table: :article_tags
              },
              %Fase.SearchView.Join{
                as: nil,
                on: "tags.id = article_tags.tag_id",
                prefix: nil,
                table: :tags
              },
              %Fase.SearchView.Join{
                as: nil,
                on: "tag_texts.tag_id = tags.id",
                prefix: nil,
                table: :tag_texts
              }
            ],
            prefix: nil,
            scope: nil,
            sort_fields: [
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :author,
                transforms: nil
              },
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :publish_date,
                transforms: nil
              }
            ],
            table_name: :articles,
            text_fields: [
              %Fase.SearchView.TextField{name: :author, transforms: nil},
              %Fase.SearchView.TextField{name: :title, transforms: nil},
              %Fase.SearchView.TextField{name: :summary, transforms: nil}
            ]
          }
        ]
      }

      assert Fase.search_view_description(ExtendedFacetSchema) ==
               expected
    end

    test "scoped sources schema" do
      expected = %Fase.SearchView.SearchViewDescription{
        sources: [
          %Fase.SearchView.Source{
            data_fields: [
              %Fase.SearchView.DataField{entries: nil, name: :title},
              %Fase.SearchView.DataField{entries: nil, name: :word_count},
              %Fase.SearchView.DataField{entries: nil, name: :publish_date}
            ],
            facet_fields: nil,
            fields: [
              %Fase.SearchView.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :word_count,
                ecto_type: :integer,
                name: :word_count,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
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
            scope: [
              %Fase.SearchView.Scope{
                key: :word_count,
                module: Fase.Test.MyApp.ScopedFacetSchema
              },
              %Fase.SearchView.Scope{
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
      expected = %Fase.SearchView.SearchViewDescription{
        id: nil,
        sources: [
          %Fase.SearchView.Source{
            data_fields: [
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :author,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :birthdate,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :source,
                transforms: nil
              }
            ],
            facet_fields: [
              %Fase.SearchView.FacetField{
                ecto_type: nil,
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :author,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil,
                transforms: nil
              },
              %Fase.SearchView.FacetField{
                ecto_type: nil,
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :source,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil,
                transforms: nil
              }
            ],
            fields: [
              %Fase.SearchView.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.SearchView.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :authors
              },
              %Fase.SearchView.Field{
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
            scope: [
              %Fase.SearchView.Scope{
                key: :source,
                module: Fase.Test.MyApp.MultipleSourcesFacetSchema
              }
            ],
            sort_fields: [
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :author,
                transforms: nil
              },
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :birthdate,
                transforms: nil
              },
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :source,
                transforms: nil
              }
            ],
            table_name: :authors,
            text_fields: [
              %Fase.SearchView.TextField{name: :author, transforms: nil},
              %Fase.SearchView.TextField{name: :birthdate, transforms: nil},
              %Fase.SearchView.TextField{name: :source, transforms: nil}
            ]
          },
          %Fase.SearchView.Source{
            data_fields: [
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :author,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :publish_date,
                transforms: nil
              },
              %Fase.SearchView.DataField{
                ecto_type: nil,
                entries: nil,
                name: :title,
                transforms: nil
              }
            ],
            facet_fields: [
              %Fase.SearchView.FacetField{
                ecto_type: nil,
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :author,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil,
                transforms: nil
              },
              %Fase.SearchView.FacetField{
                ecto_type: nil,
                hide_when_selected: false,
                hierarchy: nil,
                label_field: nil,
                name: :source,
                parent: nil,
                path: nil,
                range_bounds: nil,
                range_buckets: nil,
                transforms: nil
              },
              %Fase.SearchView.FacetField{
                ecto_type: nil,
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
                ],
                transforms: nil
              }
            ],
            fields: [
              %Fase.SearchView.Field{
                binding: nil,
                column: :source_name,
                ecto_type: :string,
                name: :source,
                prefix: nil,
                table_name: :source
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :title,
                ecto_type: :string,
                name: :title,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :summary,
                ecto_type: :string,
                name: :summary,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: nil,
                column: :publish_date,
                ecto_type: :utc_datetime,
                name: :publish_date,
                prefix: nil,
                table_name: :articles
              },
              %Fase.SearchView.Field{
                binding: :authors,
                column: :full_name,
                ecto_type: :string,
                name: :author,
                prefix: nil,
                table_name: :articles
              }
            ],
            joins: [
              %Fase.SearchView.Join{
                as: nil,
                on: "author_articles.article_id = articles.id",
                prefix: nil,
                table: :author_articles
              },
              %Fase.SearchView.Join{
                as: nil,
                on: "authors.id = author_articles.author_id",
                prefix: nil,
                table: :authors
              }
            ],
            prefix: nil,
            scope: [
              %Fase.SearchView.Scope{
                key: :source,
                module: Fase.Test.MyApp.MultipleSourcesFacetSchema
              }
            ],
            sort_fields: [
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :publish_date,
                transforms: nil
              },
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :author,
                transforms: nil
              },
              %Fase.SearchView.SortField{
                ecto_type: nil,
                name: :source,
                transforms: nil
              }
            ],
            table_name: :articles,
            text_fields: [
              %Fase.SearchView.TextField{name: :title, transforms: nil},
              %Fase.SearchView.TextField{name: :summary, transforms: nil}
            ]
          }
        ]
      }

      assert Fase.search_view_description(MultipleSourcesFacetSchema) ==
               expected
    end

    test "prefix schema" do
      expected = %Fase.SearchView.SearchViewDescription{
        sources: [
          %Fase.SearchView.Source{
            table_name: :categories,
            scope: nil,
            prefix: "classifications",
            fields: [
              %Fase.SearchView.Field{
                table_name: :source,
                prefix: nil,
                name: :source,
                ecto_type: :string,
                binding: nil,
                column: :source_name
              },
              %Fase.SearchView.Field{
                table_name: :categories,
                prefix: "classifications",
                name: :category_name,
                ecto_type: :string,
                binding: nil,
                column: :name
              },
              %Fase.SearchView.Field{
                table_name: :categories,
                prefix: "classifications",
                name: :article_title,
                ecto_type: :string,
                binding: :articles,
                column: :title
              }
            ],
            joins: [
              %Fase.SearchView.Join{
                table: :article_categories,
                on: "article_categories.category_id = categories.id",
                as: nil,
                prefix: "public"
              },
              %Fase.SearchView.Join{
                table: :articles,
                on: "articles.id = article_categories.article_id",
                as: nil,
                prefix: "public"
              }
            ],
            data_fields: [
              %Fase.SearchView.DataField{name: :article_title, entries: nil},
              %Fase.SearchView.DataField{name: :category_name, entries: nil}
            ],
            text_fields: [
              %Fase.SearchView.TextField{name: :article_title, transforms: nil},
              %Fase.SearchView.TextField{name: :category_name, transforms: nil}
            ],
            facet_fields: nil,
            sort_fields: [
              %Fase.SearchView.SortField{name: :article_title, transforms: nil},
              %Fase.SearchView.SortField{name: :category_name, transforms: nil}
            ]
          }
        ]
      }

      assert Fase.search_view_description(PrefixFacetSchema) ==
               expected
    end

    test "timestamps schema" do
      expected = %Fase.SearchView.SearchViewDescription{
        id: nil,
        sources: [
          %Fase.SearchView.Source{
            table_name: :articles,
            scope: nil,
            prefix: nil,
            fields: [
              %Fase.SearchView.Field{
                table_name: :source,
                prefix: nil,
                name: :source,
                ecto_type: :string,
                binding: nil,
                column: :source_name
              },
              %Fase.SearchView.Field{
                table_name: :articles,
                prefix: nil,
                name: :title,
                ecto_type: :string,
                binding: nil,
                column: :title
              },
              %Fase.SearchView.Field{
                table_name: :articles,
                prefix: nil,
                name: :inserted_at,
                ecto_type: :utc_datetime,
                binding: nil,
                column: :inserted_at
              },
              %Fase.SearchView.Field{
                table_name: :articles,
                prefix: nil,
                name: :updated_at,
                ecto_type: :utc_datetime,
                binding: nil,
                column: :updated_at
              }
            ],
            joins: nil,
            data_fields: [
              %Fase.SearchView.DataField{name: :title, entries: nil},
              %Fase.SearchView.DataField{name: :inserted_at, entries: nil},
              %Fase.SearchView.DataField{name: :updated_at, entries: nil}
            ],
            text_fields: nil,
            facet_fields: nil,
            sort_fields: [
              %Fase.SearchView.SortField{name: :inserted_at, transforms: nil},
              %Fase.SearchView.SortField{name: :updated_at, transforms: nil}
            ]
          }
        ]
      }

      assert Fase.search_view_description(TimestampsFacetSchema) ==
               expected
    end
  end
end
