defmodule FacetedSearch.Test.Repo.Postgres.Migration do
  use Ecto.Migration

  def change do
    create table(:authors, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:full_name, :string)
      add(:birthdate, :date)
      add(:death_date, :date)
    end

    create table(:roles, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:author_id, references(:authors, type: :uuid))
    end

    create table(:articles, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:title, :text)
      add(:summary, :text)
      add(:word_count, :integer)
      add(:publish_date, :utc_datetime)
    end

    create table(:author_articles, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:author_id, references(:authors, type: :uuid))
      add(:article_id, references(:articles, type: :uuid))
    end

    create table(:tags, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
    end

    create table(:article_tags, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:article_id, references(:articles, type: :uuid))
      add(:tag_id, references(:tags, type: :uuid))
    end

    create table(:tag_texts, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:title, :string)
      add(:tag_id, references(:tags, type: :uuid))
    end
  end
end
