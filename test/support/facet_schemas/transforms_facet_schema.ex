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
          ],
          inserted_at: [
            ecto_type: :utc_datetime
          ]
        ],
        data_fields: [
          :title,
          :author,
          :inserted_at,
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
            transforms: [
              "initcap(? collate \"fr_FR\")",
              "concat(?, ' ', length(?))"
            ]
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
        facet_fields: [
          publish_date: [
            transforms: ["to_char(?, 'YYYYMMDD')", "cast(? as integer)"],
            ecto_type: :integer
          ],
          author: [
            transforms: ["unaccent(?)"]
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
  def search_transform(_, token_or_expression, %{field: field})
      when field in [:author, :text] do
    dynamic(
      [_binding],
      fragment(
        "unaccent(?)",
        ^token_or_expression
      )
    )
  end

  def search_transform(_, token_or_expression, _), do: token_or_expression

  @impl Fase
  def search_condition(expression, %{field: field} = context)
      when field == :author do
    # Fuzzy match with levenshtein on first name
    %{query_value: value} = context

    value
    |> String.split(" ")
    |> Enum.map(
      &dynamic(
        [r],
        fragment("levenshtein(split_part(?,' ',1), ?) <= 2", ^expression, ^&1)
      )
    )
    |> Enum.reduce(fn dynamic, acc ->
      dynamic([r], ^acc or ^dynamic)
    end)
  end

  def search_condition(expression, %{field: field} = context)
      when field == :inserted_at do
    %{filter: filter, filter_opts: filter_opts, query_value: value} = context
    timezone = Keyword.fetch!(filter_opts, :timezone)

    expr =
      dynamic(
        [r],
        fragment(
          "((? AT TIME ZONE 'utc') AT TIME ZONE ?)",
          ^expression,
          ^timezone
        )
      )

    case filter.op do
      :>= -> dynamic([r], ^expr >= ^value)
      :<= -> dynamic([r], ^expr <= ^value)
    end
  end

  def search_condition(_, _), do: nil
end
