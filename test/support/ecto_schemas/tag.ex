defmodule Fase.Test.MyApp.Tag do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.ArticleTag
  alias Fase.Test.MyApp.TagText

  schema "tags" do
    field :name, :string

    has_one :tag_text, TagText
    has_many :article_tags, ArticleTag
  end
end
