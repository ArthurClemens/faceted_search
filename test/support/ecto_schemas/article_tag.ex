defmodule Fase.Test.MyApp.ArticleTag do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.Article
  alias Fase.Test.MyApp.Tag

  schema "article_tags" do
    belongs_to :article, Article
    belongs_to :tag, Tag
  end
end
