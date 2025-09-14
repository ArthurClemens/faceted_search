defmodule Fase.Test.MyApp.TimestampsFacetSchema do
  @moduledoc """
  A simple facet schema with timestamps to filter and sort on.
  """

  @options [
    sources: [
      articles: [
        fields: [
          title: [
            ecto_type: :string
          ],
          inserted_at: [
            ecto_type: :utc_datetime
          ],
          updated_at: [
            ecto_type: :utc_datetime
          ]
        ],
        data_fields: [
          :title,
          :inserted_at,
          :updated_at
        ],
        sort_fields: [
          :inserted_at,
          :updated_at
        ]
      ]
    ]
  ]

  use Fase, @options

  def schema_options, do: @options
end
