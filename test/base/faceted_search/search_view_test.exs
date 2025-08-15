defmodule FacetedSearch.Test.SearchViewTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.Test.MyApp.SimpleFacetSchema

  describe "the search_view_name/2 function returns the normalized Postgres materialized view name generated from the view ID" do
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

  describe "the search_view_description/1 function" do
    test "with the simple facet schema" do
      expected = %FacetedSearch.SearchViewDescription{
        sources: [
          %FacetedSearch.Source{
            table_name: :articles,
            scopes: nil,
            prefix: nil,
            fields: [
              %FacetedSearch.Field{
                table_name: :articles,
                name: :title,
                ecto_type: :string,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :content,
                ecto_type: :string,
                binding: nil,
                field: nil
              },
              %FacetedSearch.Field{
                table_name: :articles,
                name: :draft,
                ecto_type: :boolean,
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
              %FacetedSearch.DataField{name: :draft, entries: nil},
              %FacetedSearch.DataField{name: :publish_date, entries: nil}
            ],
            text_fields: [:title, :content],
            sort_fields: [
              %FacetedSearch.SortField{name: :publish_date, cast: nil},
              %FacetedSearch.SortField{name: :draft, cast: nil}
            ],
            facet_fields: [
              %FacetedSearch.FacetField{
                name: :draft,
                hide_when_selected: false,
                label_field: nil,
                range_bounds: nil,
                range_buckets: nil,
                hierarchy: nil,
                parent: nil,
                path: nil
              }
            ]
          }
        ]
      }

      assert FacetedSearch.search_view_description(SimpleFacetSchema) ==
               expected
    end
  end
end
