defmodule FacetedSearch.Test.SchemaTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.Test.MyApp.SimpleFacetSchema

  test "options/1 returns the provided schema options" do
    expected = [
      {:module, SimpleFacetSchema},
      {:sources,
       [
         articles: [
           fields: [
             title: [ecto_type: :string],
             content: [ecto_type: :string],
             draft: [ecto_type: :boolean],
             publish_date: [ecto_type: :utc_datetime]
           ],
           data_fields: [:title, :draft, :publish_date],
           text_fields: [:title, :content],
           sort_fields: [:publish_date, :draft],
           facet_fields: [
             :draft
           ]
         ]
       ]}
    ]

    assert FacetedSearch.options(SimpleFacetSchema) == expected
  end

  test "ecto_schema/2 returns the Ecto schema for the search view" do
    view_id = "articles"
    expected = {"fv_articles", SimpleFacetSchema}
    assert FacetedSearch.ecto_schema(SimpleFacetSchema, view_id) == expected
  end
end
