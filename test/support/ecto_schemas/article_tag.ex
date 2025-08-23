defmodule FacetedSearch.Test.MyApp.ArticleTag do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.Article
  alias FacetedSearch.Test.MyApp.Tag

  schema "article_tags" do
    belongs_to :article, Article
    belongs_to :tag, Tag
  end
end
