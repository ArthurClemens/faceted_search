defmodule FacetedSearch.Test.MyApp.Category do
  @moduledoc false

  use FacetedSearch.Test.EctoSchemaExtension

  alias FacetedSearch.Test.MyApp.ArticleCategory

  @schema_prefix "classifications"

  schema "categories" do
    field :name, :string

    has_many :article_categories, ArticleCategory
  end
end
