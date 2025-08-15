defmodule FacetedSearch.Test.Repo.Postgres.Migration do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add(:name, :string)
    end

    create table(:roles) do
      add(:name, :string)
      add(:author_id, references(:authors))
    end

    create table(:articles) do
      add(:title, :text)
      add(:content, :text)
      add(:publish_date, :utc_datetime)
    end

    create table(:author_articles) do
      add(:author_id, references(:authors))
      add(:article_id, references(:articles))
    end

    create table(:tags) do
      add(:name, :string)
    end

    create table(:article_tags) do
      add(:article_id, references(:articles))
      add(:tag_id, references(:tags))
    end
  end
end
