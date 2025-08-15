defmodule FacetedSearch.Test.NimbleSchemaTest do
  use ExUnit.Case, async: true

  alias FacetedSearch.NimbleSchema
  alias FacetedSearch.Test.MyApp.SimpleFacetSchema

  describe "the validate!/2 function" do
    test "a valid schema" do
      options = [
        sources: [
          articles: [
            fields: [
              title: [
                ecto_type: :string
              ],
              content: [
                ecto_type: :string
              ],
              draft: [
                ecto_type: :boolean
              ],
              publish_date: [
                ecto_type: :date
              ]
            ],
            data_fields: [
              :title,
              :draft,
              :publish_date
            ],
            text_fields: [
              :title,
              :content
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

    test "invalid schema raises (no sources)" do
      options = []

      assert_raise FacetedSearch.Errors.InvalidOptionsError,
                   "required :sources option not found, received options: [:module]",
                   fn ->
                     validate_options(options)
                   end
    end

    test "invalid schema raises (fields: missing ecto_type)" do
      options = [
        sources: [
          articles: [
            fields: [
              :title
            ]
          ]
        ]
      ]

      assert_raise FacetedSearch.Errors.InvalidOptionsError,
                   "invalid value for :fields option: expected keyword list, got: [:title] (in options [:sources, :articles])",
                   fn ->
                     validate_options(options)
                   end
    end
  end

  defp validate_options(options) do
    NimbleSchema.validate!(
      Keyword.put(options, :module, SimpleFacetSchema),
      SimpleFacetSchema
    )
  end
end
