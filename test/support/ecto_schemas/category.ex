defmodule Fase.Test.MyApp.Category do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.ArticleCategory

  @schema_prefix "classifications"

  schema "categories" do
    field :name, :string

    has_many :article_categories, ArticleCategory
  end
end
