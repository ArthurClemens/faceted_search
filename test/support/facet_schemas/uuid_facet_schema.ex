defmodule Fase.Test.MyApp.UUIDFacetSchema do
  @moduledoc """
  Facet schema to test processing UUIDs.
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
          author: [
            binding: :authors,
            column: :id,
            ecto_type: :uuid
          ]
        ],
        data_fields: [
          author: [
            transforms: ["cast(? as text)"],
            ecto_type: :string
          ]
        ],
        text_fields: [
          :author
        ],
        facet_fields: [
          :author
        ],
        sort_fields: [
          author: [
            transforms: ["cast(? as text)"],
            ecto_type: :string
          ]
        ]
      ]
    ]
  ]

  use Fase, @options

  def schema_options, do: @options
end
