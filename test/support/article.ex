defmodule FacetedSearch.Test.MyApp.Article do
  @moduledoc false
  use Ecto.Schema

  schema "articles" do
    field :title, :string
    field :content, :string
    field :draft, :boolean
    field :publish_date, :utc_datetime
  end
end
