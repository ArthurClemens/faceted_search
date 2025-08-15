defmodule FacetedSearch.Test.MyApp.SimpleFacetSchema do
  @moduledoc """
  A simple facet schema:
  - a single source
  - no joined tables
  - simple facets
  - no callbacks
  """

  @options [
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
            ecto_type: :utc_datetime
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
        sort_fields: [
          :publish_date,
          :draft
        ],
        facet_fields: [
          :draft
        ]
      ]
    ]
  ]

  use FacetedSearch, @options

  def schema_options, do: @options
end
