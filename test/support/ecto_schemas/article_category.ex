defmodule FacetedSearch.Test.MyApp.ArticleCategory do
  @moduledoc false

  use FacetedSearch.Test.EctoSchemaExtension

  alias FacetedSearch.Test.MyApp.Article
  alias FacetedSearch.Test.MyApp.Category

  schema "article_categories" do
    belongs_to :article, Article
    belongs_to :category, Category
  end
end
