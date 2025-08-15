defmodule FacetedSearch.Test.MyApp.ExpandedFacetSchema do
  @moduledoc """
  A facet schema that includes:
  - multiple sources
  - joined tables
  - multiple facets
  - callbacks
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
          content: [
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
          :author,
          :title,
          :publish_date
        ],
        text_fields: [
          :author,
          :title,
          :content
        ],
        sort_fields: [
          :author,
          :publish_date
        ],
        facet_fields: [
          :author
        ]
      ]
    ]
  ]

  use FacetedSearch, @options

  def schema_options, do: @options

  def option_label(:draft, value, _) do
    if value, do: "Yes", else: "No"
  end

  def option_label(_, _, _), do: nil
end
