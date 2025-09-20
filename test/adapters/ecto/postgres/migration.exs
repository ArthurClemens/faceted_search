defmodule Fase.Test.Repo.Postgres.Migration do
  use Ecto.Migration

  alias Ecto.Adapters.SQL

  @schema_prefixes ["classifications"]

  def change do
    Enum.each(@schema_prefixes, fn schema_prefix ->
      sql = ~s(CREATE SCHEMA "#{schema_prefix}")
      SQL.query(Fase.Test.Repo, sql, [])
    end)

    # unaccent extension and function
    execute(
      "CREATE EXTENSION IF NOT EXISTS unaccent;",
      "DROP EXTENSION IF EXISTS unaccent;"
    )

    # schema_prefix classifications

    create table(:categories, primary_key: false, prefix: "classifications") do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
    end

    # schema_prefix public

    create table(:authors, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:full_name, :string)
      add(:birthdate, :date)
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
      add(:draft, :boolean)

      timestamps(type: :utc_datetime)
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

    create table(:article_categories, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(:article_id, references(:articles, type: :uuid))

      add(
        :category_id,
        references(:categories, prefix: "classifications", type: :uuid)
      )
    end
  end
end
