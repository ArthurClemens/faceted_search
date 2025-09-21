defmodule Fase.Test.MyApp.TransformsFacetSchema do
  @moduledoc """
  A facet schema to test transforms
  """

  import Ecto.Query, warn: false

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
          text: [
            ecto_type: :string
          ],
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
          ],
          draft: [
            ecto_type: :boolean
          ],
          word_count: [
            ecto_type: :integer
          ]
        ],
        data_fields: [
          :title,
          :author,
          publish_date: [
            transforms: ["to_char(?, 'YYYY-MM-DD')"],
            ecto_type: :string
          ],
          indicators: [
            word_count: [
              transforms: ["cast(? as text)"],
              ecto_type: :string
            ]
          ]
        ],
        text_fields: [
          :summary,
          title: [
            transforms: ["initcap(?)", "concat(?, ' ', length(?))"]
          ],
          author: [
            transforms: ["unaccent(?)"]
          ],
          publish_date: [
            transforms: ["to_char(?, 'YYYY-MM-DD')"]
          ],
          draft: [
            transforms: ["cast(NOT ? AS integer)"]
          ]
        ],
        sort_fields: [
          :author,
          publish_date: [
            transforms: ["to_char(?, 'YYYYMMDD')", "cast(? as integer)"],
            ecto_type: :integer
          ]
        ]
      ]
    ]
  ]

  use Fase, @options

  def schema_options, do: @options

  @impl Fase
  def search_transform(_, term_or_expression, %{field: field})
      when field in [:author, :text] do
    dynamic(
      [_binding],
      fragment(
        "unaccent(?)",
        ^term_or_expression
      )
    )
  end

  def search_transform(_, term_or_expression, _), do: term_or_expression
end
