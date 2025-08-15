defmodule FacetedSearch.Test.Repo.Postgres.Migration do
  use Ecto.Migration

  def change do
    create table(:articles) do
      add(:title, :text)
      add(:content, :text)
      add(:draft, :boolean)
      add(:publish_date, :utc_datetime)
    end
  end
end
