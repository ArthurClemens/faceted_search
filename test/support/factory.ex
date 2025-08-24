defmodule FacetedSearch.Test.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: FacetedSearch.Test.Repo

  alias FacetedSearch.Test.MyApp.Article
  alias FacetedSearch.Test.MyApp.ArticleTag
  alias FacetedSearch.Test.MyApp.Author
  alias FacetedSearch.Test.MyApp.AuthorArticle
  alias FacetedSearch.Test.MyApp.Role
  alias FacetedSearch.Test.MyApp.Tag
  alias FacetedSearch.Test.MyApp.TagText
  alias FacetedSearch.Test.Repo

  @tags [
    "archives",
    "books",
    "culture",
    "digital-humanities",
    "emotion",
    "history",
    "interdisciplinary",
    "language_analysis",
    "literature",
    "manuscripts",
    "materiality",
    "memory",
    "modernism",
    "music",
    "oral-history",
    "politics",
    "religion",
    "semiotics",
    "theory",
    "travel-writing"
  ]

  @tag_titles %{
    "archives" => "Archives",
    "books" => "Books",
    "culture" => "Culture",
    "digital-humanities" => "Digital humanities",
    "emotion" => "Emotion",
    "history" => "History",
    "interdisciplinary" => "Interdisciplinary",
    "language_analysis" => "Language analysis: Critical reading",
    "literature" => "Literature",
    "manuscripts" => "Manuscripts",
    "materiality" => "Materiality",
    "memory" => "Memory",
    "modernism" => "Modernism",
    "music" => "Music",
    "oral-history" => "Oral history",
    "politics" => "Politics",
    "religion" => "Religion",
    "semiotics" => "Semiotics",
    "theory" => "Theory",
    "travel-writing" => "Travel writing"
  }

  @articles [
    %{
      title:
        "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises",
      summary:
        "Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood.",
      tags: ["politics", "history", "language_analysis"],
      author: "Helena van Dijk",
      word_count: 3473
    },
    %{
      title:
        "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
      summary:
        "Analyzes the layered temporal structures present in oral testimonies from post-war societies, integrating insights from history, psychology, and narratology.",
      tags: ["memory", "oral-history", "interdisciplinary"],
      author: "Helena van Dijk",
      word_count: 2871
    },
    %{
      title:
        "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
      summary:
        "Explores how symbolic motifs circulated through manuscript production, illuminating networks of cultural exchange in medieval Europe.",
      tags: ["semiotics", "manuscripts", "history"],
      author: "Mateo Alvarez",
      word_count: 5591
    },
    %{
      title:
        "The Grammar of Resistance: Syntax and Subversion in 20th-Century Protest Literature",
      summary:
        "Investigates how unconventional syntax and grammar functioned as tools of political resistance in literary works tied to protest movements.",
      tags: ["literature", "politics", "language_analysis"],
      author: "Mateo Alvarez",
      word_count: 3627
    },
    %{
      title:
        "Emotional Cartography: Mapping Affective Landscapes in Victorian Travel Writing",
      summary:
        "Charts the representation of emotions in Victorian travel narratives to show how writers spatialized feelings in relation to foreign landscapes.",
      tags: ["literature", "emotion", "travel-writing"],
      author: "Aisha Rahman",
      word_count: 6131
    },
    %{
      title:
        "From Papyrus to Pixel: Materiality and Meaning in the Evolution of the Book",
      summary:
        "Traces the transformation of the book as a material and symbolic object from antiquity to the digital age, emphasizing shifts in reading practices.",
      tags: ["books", "materiality", "history"],
      author: "Aisha Rahman",
      word_count: 2198
    },
    %{
      title: "Spectral Agency: Ghost Narratives as Cultural Memory Archives",
      summary:
        "Considers ghost stories as repositories of collective memory, revealing their role in preserving suppressed or marginalized histories.",
      tags: ["memory", "literature", "culture"],
      author: "Sven Olsson",
      word_count: 4898
    },
    %{
      title:
        "Narrative Entropy: Chaos Theory and Structure in Modernist Fiction",
      summary:
        "Applies principles from chaos theory to explain the apparent disorder and hidden patterning in selected modernist novels.",
      tags: ["literature", "modernism", "theory"],
      author: "Sven Olsson",
      word_count: 6581
    },
    %{
      title:
        "Soundscapes of Faith: Acoustic Analysis of Medieval Cathedral Chant",
      summary:
        "Combines acoustic modeling and musicology to reconstruct the sonic environment of medieval chant within cathedral spaces.",
      tags: ["music", "religion", "history"],
      author: "Jean-Marie Leclerc",
      word_count: 3352
    },
    %{
      title:
        "Datafied Memory: Digital Humanities Approaches to Holocaust Testimony Archives",
      summary:
        "Explores computational methods for indexing, visualizing, and analyzing large-scale Holocaust testimony datasets.",
      tags: ["digital-humanities", "memory", "archives"],
      author: "Jean-Marie Leclerc",
      word_count: 7643
    }
  ]

  @authors [
    "Helena van Dijk",
    "Mateo Alvarez",
    "Aisha Rahman",
    "Sven Olsson",
    "Jean-Marie Leclerc"
  ]

  @roles [
    :author,
    :editor,
    :assistant
  ]

  def init_resources(opts) do
    ExMachina.Sequence.reset()

    article_count = Keyword.get(opts, :article_count)

    Enum.each(@tags, fn name ->
      tag = insert(%Tag{name: name})

      insert(%TagText{
        title: @tag_titles[name],
        tag_id: tag.id
      })
    end)

    Enum.each(@authors, fn name ->
      author = insert(%Author{name: name})

      insert(%Role{
        name: sequence(:role_name, @roles),
        author_id: author.id
      })
    end)

    build_list(article_count, :insert_article)
  end

  def insert_article_factory do
    article_data = build(:article_data)

    article = %Article{
      title: article_data.title,
      summary: article_data.summary,
      word_count: article_data.word_count,
      publish_date:
        DateTime.utc_now()
        |> DateTime.add(
          -1 * article_publish_date_offset(article_data.title),
          :day
        )
        |> DateTime.truncate(:second)
    }

    article = insert(article, returning: true)

    article_data.tags
    |> Enum.each(fn name ->
      tag = apply(Repo, :get_by, [Tag, %{name: name}])

      insert(%ArticleTag{
        article_id: article.id,
        tag_id: tag.id
      })
    end)

    author = apply(Repo, :get_by, [Author, %{name: article_data.author}])

    insert(%AuthorArticle{
      article_id: article.id,
      author_id: author.id
    })

    article
  end

  def article_data_factory do
    sequence(:article_data, @articles)
  end

  def author_name_factory do
    sequence(:author_name, @authors)
  end

  defp article_publish_date_offset(title) do
    {min_code, max_code} = article_char_codes() |> min_max_article_char_codes()
    article_char_code = article_char_code(title)
    article_publish_date_step = 1 / (max_code - min_code) * 140

    Kernel.round((max_code - article_char_code) * article_publish_date_step)
  end

  defp article_char_codes do
    Enum.map(
      @articles,
      &(&1.title |> article_char_code())
    )
  end

  defp article_char_code(title) do
    String.first(title) |> String.to_charlist() |> hd
  end

  defp min_max_article_char_codes(article_char_codes) do
    {Enum.min(article_char_codes), Enum.max(article_char_codes)}
  end
end
