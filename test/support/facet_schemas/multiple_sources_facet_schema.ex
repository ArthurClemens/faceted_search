defmodule FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema do
  @moduledoc """
  A facet schema with multiple sources.
  """

  @shared_scope_keys [:source]

  @options [
    sources: [
      authors: [
        scope_keys: @shared_scope_keys,
        fields: [
          author: [
            binding: :authors,
            column: :full_name,
            ecto_type: :string
          ],
          birthdate: [
            ecto_type: :date
          ]
        ],
        data_fields: [
          :author,
          :birthdate,
          :source
        ],
        text_fields: [
          :author,
          :birthdate,
          :source
        ],
        sort_fields: [
          :author,
          :birthdate,
          :source
        ],
        facet_fields: [
          :author,
          :source
        ]
      ],
      articles: [
        scope_keys: @shared_scope_keys,
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
            column: :full_name,
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
          :author,
          :source
        ],
        facet_fields: [
          :author,
          :source
        ]
      ]
    ]
  ]

  def scope_by(:source, %{source: source}) do
    %{
      column: :source,
      comparison: "=",
      value: source
    }
  end

  use FacetedSearch, @options

  def schema_options, do: @options
end
