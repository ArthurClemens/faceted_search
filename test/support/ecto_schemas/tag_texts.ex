defmodule Fase.Test.MyApp.TagText do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.Tag

  schema "tag_texts" do
    field :title, :string

    belongs_to :tag, Tag
  end
end
