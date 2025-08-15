defmodule FacetedSearch.Test.MyApp.Tag do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.ArticleTag

  schema "tags" do
    field :name, :string

    has_many :article_tags, ArticleTag
  end
end
