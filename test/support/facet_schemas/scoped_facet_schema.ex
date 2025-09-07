defmodule FacetedSearch.Test.MyApp.ScopedFacetSchema do
  @moduledoc """
  A facet schema with a scope and scope callback.
  """

  @options [
    sources: [
      articles: [
        scope_keys: [:word_count, :publish_date],
        fields: [
          title: [
            ecto_type: :string
          ],
          word_count: [
            ecto_type: :integer
          ],
          publish_date: [
            ecto_type: :utc_datetime
          ]
        ],
        data_fields: [
          :title,
          :word_count,
          :publish_date
        ]
      ]
    ]
  ]

  def scope_by(:word_count, %{word_count: word_count}) do
    %{
      column: :word_count,
      comparison: ">",
      value: word_count
    }
  end

  def scope_by(:publish_date, %{publish_date: publish_date}) do
    %{
      column: :publish_date,
      comparison: ">",
      value: publish_date |> DateTime.to_iso8601(:basic)
    }
  end

  def scope_by(_, _), do: nil

  use FacetedSearch, @options

  def schema_options, do: @options
end
