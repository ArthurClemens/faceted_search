defmodule Fase.Test.MyApp.Article do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.ArticleCategory
  alias Fase.Test.MyApp.ArticleTag
  alias Fase.Test.MyApp.AuthorArticle

  schema "articles" do
    field :title, :string
    field :summary, :string
    field :word_count, :integer
    field :publish_date, :utc_datetime
    field :draft, :boolean

    has_many :author_articles, AuthorArticle
    has_many :article_tags, ArticleTag
    has_many :article_categories, ArticleCategory

    timestamps(type: :utc_datetime)
  end
end
