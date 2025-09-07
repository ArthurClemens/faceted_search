defmodule Fase.Test.MyApp.Author do
  @moduledoc false

  use Fase.Test.EctoSchemaExtension

  alias Fase.Test.MyApp.AuthorArticle
  alias Fase.Test.MyApp.Role

  schema "authors" do
    field :full_name, :string
    field :birthdate, :date

    has_one :role, Role
    has_many :author_articles, AuthorArticle
  end
end
