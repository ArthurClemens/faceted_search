defmodule FacetedSearch.Test.MyApp.Author do
  @moduledoc false

  use FacetedSearch.Test.EctoSchemaExtension

  alias FacetedSearch.Test.MyApp.AuthorArticle
  alias FacetedSearch.Test.MyApp.Role

  schema "authors" do
    field :full_name, :string
    field :birthdate, :date
    field :death_date, :date

    has_one :role, Role
    has_many :author_articles, AuthorArticle
  end
end
