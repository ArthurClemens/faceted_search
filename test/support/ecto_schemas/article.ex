defmodule FacetedSearch.Test.MyApp.Article do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.ArticleTag
  alias FacetedSearch.Test.MyApp.AuthorArticle

  schema "articles" do
    field :title, :string
    field :content, :string
    field :publish_date, :utc_datetime

    has_many :author_articles, AuthorArticle
    has_many :article_tags, ArticleTag
  end
end
