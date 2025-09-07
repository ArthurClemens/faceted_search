defmodule Fase.Test.MyApp.ArticleCategory do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.Article
  alias Fase.Test.MyApp.Category

  schema "article_categories" do
    belongs_to :article, Article
    belongs_to :category, Category
  end
end
