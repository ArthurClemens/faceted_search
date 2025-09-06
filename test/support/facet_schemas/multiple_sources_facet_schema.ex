defmodule FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema do
  @moduledoc """
  A facet schema with multiple sources.
  """

  @options [
    sources: [
      authors: [
        fields: [
          full_name: [
            ecto_type: :string
          ],
          birthdate: [
            ecto_type: :date
          ],
          death_date: [
            ecto_type: :date
          ]
        ],
        data_fields: [
          :full_name,
          :birthdate,
          :death_date
        ],
        text_fields: [
          :full_name,
          :birthdate
        ],
        sort_fields: [
          :full_name,
          :birthdate
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
