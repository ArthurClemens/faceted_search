defmodule FacetedSearch.Test.MyApp.Author do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.AuthorArticle
  alias FacetedSearch.Test.MyApp.Role

  schema "authors" do
    field :name, :string

    has_one :role, Role
    has_many :author_articles, AuthorArticle
  end
end
