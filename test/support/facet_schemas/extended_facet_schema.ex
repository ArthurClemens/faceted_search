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
          title: [
            ecto_type: :string
          ],
          summary: [
            ecto_type: :string
          ],
          publish_date: [
            ecto_type: :utc_datetime
          ],
          word_count: [
            ecto_type: :integer
          ],
          tags: [
            binding: :tags,
            field: :name,
            ecto_type: {:array, :string}
          ],
          tag_titles: [
            binding: :tag_texts,
            field: :title,
            ecto_type: {:array, :string}
          ],
          author: [
            binding: :authors,
            field: :name,
            ecto_type: :string
          ]
        ],
        data_fields: [
          :title,
          :author,
          :tags,
          :tag_titles,
          :publish_date,
          :word_count
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
          ]
        ]
      ]
    ]
  ]

  use FacetedSearch, @options

  def schema_options, do: @options

  def option_label(:word_count, value, _) do
    {bounds, _bucket} = value

    case bounds do
      [:lower, to] -> "0 - #{to}"
      [from, :upper] -> "more than #{from}"
      [from, to] -> "#{from}-#{to}"
    end
  end

  def option_label(:publish_date, value, _) do
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

  def option_label(_, _, _), do: nil
end
