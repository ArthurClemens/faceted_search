defmodule FacetedSearch.Test.MyApp.AuthorArticle do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.Article
  alias FacetedSearch.Test.MyApp.Author

  schema "author_articles" do
    belongs_to :author, Author
    belongs_to :article, Article
  end
end
