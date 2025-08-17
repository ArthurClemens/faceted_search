defmodule FacetedSearch.Test.MyApp.TagText do
  @moduledoc false

  use Ecto.Schema

  alias FacetedSearch.Test.MyApp.Tag

  schema "tag_texts" do
    field :title, :string

    belongs_to :tag, Tag
  end
end
