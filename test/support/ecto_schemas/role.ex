defmodule FacetedSearch.Test.MyApp.Role do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.Author

  schema "roles" do
    field :name, Ecto.Enum, values: [:author, :editor, :assistant]

    belongs_to :author, Author
  end
end
