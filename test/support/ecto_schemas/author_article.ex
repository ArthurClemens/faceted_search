defmodule Fase.Test.MyApp.AuthorArticle do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.Article
  alias Fase.Test.MyApp.Author

  schema "author_articles" do
    belongs_to :author, Author
    belongs_to :article, Article
  end
end
