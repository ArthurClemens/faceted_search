defmodule Fase.Test.MyApp.ExtendedFacetSchema do
  @moduledoc """
  A facet schema that includes:
  - joined tables
  - facets
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
          ],
          article_tags: [
            on: "article_tags.article_id = articles.id"
          ],
          tags: [
            on: "tags.id = article_tags.tag_id"
          ],
          tag_texts: [
            on: "tag_texts.tag_id = tags.id"
          ]
        ],
        fields: [
          id: [
            ecto_type: :uuid
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
          draft: [
            ecto_type: :boolean
          ],
          word_count: [
            ecto_type: :integer
          ],
          tags: [
            binding: :tags,
            column: :name,
            ecto_type: {:array, :string}
          ],
          tag_titles: [
            binding: :tag_texts,
            column: :title,
            ecto_type: {:array, :string}
          ],
          author: [
            binding: :authors,
            column: :full_name,
            ecto_type: :string
          ]
        ],
        data_fields: [
          :id,
          :title,
          :author,
          :tags,
          :tag_titles,
          draft: [
            transforms: ["cast(? as integer)"],
            ecto_type: :integer
          ],
          indicators: [
            word_count: [
              transforms: ["cast(? as text)"],
              ecto_type: :string
            ],
            type: [
              binding: :tags,
              column: :name
            ]
          ]
        ],
        text_fields: [
          :author,
          :title,
          :summary
        ],
        sort_fields: [
          :author,
          :publish_date
        ],
        facet_fields: [
          :author,
          tags: [
            label: :tag_titles
          ],
          word_count: [
            number_range_bounds: [2000, 4000, 6000, 8000]
          ],
          publish_date: [
            date_range_bounds: [
              "now() - interval '1 year'",
              "now() - interval '3 month'",
              "now() - interval '1 month'",
              "now() - interval '1 week'",
              "now() - interval '1 day'"
            ]
          ],
          hierarchies: [
            category_author: [
              path: [:author]
            ],
            category_author_tags: [
              path: [:author, :tags]
            ],
            category_tags: [
              path: [:tags]
            ],
            category_tags_author: [
              path: [:tags, :author]
            ]
          ]
        ]
      ]
    ],
    default_order: %{
      order_by: [:sort_publish_date, :sort_author],
      order_directions: [:desc, :asc]
    }
  ]

  use Fase, @options

  def schema_options, do: @options

  def option_label(:word_count, value, _, scope) do
    {bounds, _bucket} = value
    locale = scope[:locale]

    case locale do
      "fr" ->
        case bounds do
          [:lower, to] -> "de 0 à #{to}"
          [from, :upper] -> "plus de #{from}"
          [from, to] -> "de #{from} à #{to}"
        end

      _ ->
        case bounds do
          [:lower, to] -> "0 - #{to}"
          [from, :upper] -> "more than #{from}"
          [from, to] -> "#{from}-#{to}"
        end
    end
  end

  def option_label(:publish_date, value, _, _) do
    {bounds, _bucket} = value

    case bounds do
      [:lower, "now() - interval '1 year'"] ->
        "older than 1 year"

      ["now() - interval '1 year'", "now() - interval '3 month'"] ->
        "last year"

      ["now() - interval '3 month'", "now() - interval '1 month'"] ->
        "last quarter"

      ["now() - interval '1 month'", "now() - interval '1 week'"] ->
        "last month"

      ["now() - interval '1 week'", "now() - interval '1 day'"] ->
        "last week"

      ["now() - interval '1 day'", :upper] ->
        "today"
    end
  end

  def option_label(_, _, _, _), do: nil
end
