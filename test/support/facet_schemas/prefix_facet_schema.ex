defmodule Fase.Test.MyApp.PrefixFacetSchema do
  @moduledoc """
  A facet schema that includes schema prefixes.
  """

  @options [
    sources: [
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
          category_name: [
            column: :name,
            ecto_type: :string
          ],
          article_title: [
            binding: :articles,
            column: :title,
            ecto_type: :string
          ]
        ],
        data_fields: [
          :article_title,
          :category_name
        ],
        text_fields: [
          :article_title,
          :category_name
        ],
        sort_fields: [
          :article_title,
          :category_name
        ]
      ]
    ]
  ]

  use Fase, @options

  def schema_options, do: @options
end
