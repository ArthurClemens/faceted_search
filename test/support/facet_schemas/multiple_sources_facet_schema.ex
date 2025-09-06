defmodule FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema do
  @moduledoc """
  A facet schema with multiple sources.
  """

  @options [
    sources: [
      authors: [
        fields: [
          author: [
            binding: :authors,
            field: :full_name,
            ecto_type: :string
          ],
          birthdate: [
            ecto_type: :date
          ]
        ],
        data_fields: [
          :author,
          :birthdate
        ],
        text_fields: [
          :author,
          :birthdate
        ],
        sort_fields: [
          :author,
          :birthdate
        ],
        facet_fields: [
          :author,
          :source
        ]
      ],
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
            field: :full_name,
            ecto_type: :string
          ]
        ],
        data_fields: [
          :author,
          :publish_date,
          :title
        ],
        text_fields: [
          :title,
          :summary
        ],
        sort_fields: [
          :publish_date,
          :author
        ],
        facet_fields: [
          :author,
          :source
        ]
      ]
    ]
  ]

  use FacetedSearch, @options

  def schema_options, do: @options
end
