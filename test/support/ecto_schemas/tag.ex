defmodule FacetedSearch.Test.MyApp.Tag do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.ArticleTag
  alias FacetedSearch.Test.MyApp.TagText

  schema "tags" do
    field :name, :string

    has_one :tag_text, TagText
    has_many :article_tags, ArticleTag
  end
end
