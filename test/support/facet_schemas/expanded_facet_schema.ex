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
          content: [
            ecto_type: :string
          ],
          publish_date: [
            ecto_type: :utc_datetime
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
          :author,
          tags: [
            label: :tag_titles
          ]
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
