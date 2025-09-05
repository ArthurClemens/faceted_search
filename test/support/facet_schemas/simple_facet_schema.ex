defmodule FacetedSearch.Test.MyApp.SimpleFacetSchema do
  @moduledoc """
  A simple facet schema:
  - a single source
  - no facets
  - no callbacks
  """

  @options [
    sources: [
      articles: [
        joins: [
          author_articles: [
            on: "author_articles.article_id = articles.id"
          ],
          authors: [
            on: "authors.id = author_articles.author_id"
          ]
        ],
        fields: [
          title: [
            ecto_type: :string
          ],
          summary: [
            ecto_type: :string
          ],
          publish_date: [
            ecto_type: :utc_datetime
          ],
          author: [
            binding: :authors,
            field: :name,
            ecto_type: :string
          ]
        ],
        data_fields: [
          :title,
          :publish_date,
          :author
        ],
        text_fields: [
          :title,
          :summary
        ],
        sort_fields: [
          :publish_date,
          :author
        ]
      ]
    ]
  ]

  use FacetedSearch, @options

  def schema_options, do: @options
end
