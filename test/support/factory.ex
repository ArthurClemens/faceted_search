defmodule FacetedSearch.Test.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: FacetedSearch.Test.Repo

  alias FacetedSearch.Test.MyApp.Article
  alias FacetedSearch.Test.MyApp.ArticleTag
  alias FacetedSearch.Test.MyApp.Author
  alias FacetedSearch.Test.MyApp.AuthorArticle
  alias FacetedSearch.Test.MyApp.Role
  alias FacetedSearch.Test.MyApp.Tag
  alias FacetedSearch.Test.Repo

  @tags [
    "politics",
    "history",
    "language",
    "memory",
    "oral-history",
    "interdisciplinary",
    "semiotics",
    "manuscripts",
    "literature",
    "emotion",
    "travel-writing",
    "books",
    "materiality",
    "culture",
    "modernism",
    "theory",
    "music",
    "religion",
    "digital-humanities",
    "archives"
  ]

  @articles [
    %{
      title:
        "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises",
      summary:
        "Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood.",
      tags: ["politics", "history", "language"],
      author: "Helena van Dijk"
    },
    %{
      title:
        "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
      summary:
        "Analyzes the layered temporal structures present in oral testimonies from post-war societies, integrating insights from history, psychology, and narratology.",
      tags: ["memory", "oral-history", "interdisciplinary"],
      author: "Helena van Dijk"
    },
    %{
      title:
        "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
      summary:
        "Explores how symbolic motifs circulated through manuscript production, illuminating networks of cultural exchange in medieval Europe.",
      tags: ["semiotics", "manuscripts", "history"],
      author: "Mateo Alvarez"
    },
    %{
      title:
        "The Grammar of Resistance: Syntax and Subversion in 20th-Century Protest Literature",
      summary:
        "Investigates how unconventional syntax and grammar functioned as tools of political resistance in literary works tied to protest movements.",
      tags: ["literature", "politics", "language"],
      author: "Mateo Alvarez"
    },
    %{
      title:
        "Emotional Cartography: Mapping Affective Landscapes in Victorian Travel Writing",
      summary:
        "Charts the representation of emotions in Victorian travel narratives to show how writers spatialized feelings in relation to foreign landscapes.",
      tags: ["literature", "emotion", "travel-writing"],
      author: "Aisha Rahman"
    },
    %{
      title:
        "From Papyrus to Pixel: Materiality and Meaning in the Evolution of the Book",
      summary:
        "Traces the transformation of the book as a material and symbolic object from antiquity to the digital age, emphasizing shifts in reading practices.",
      tags: ["books", "materiality", "history"],
      author: "Aisha Rahman"
    },
    %{
      title: "Spectral Agency: Ghost Narratives as Cultural Memory Archives",
      summary:
        "Considers ghost stories as repositories of collective memory, revealing their role in preserving suppressed or marginalized histories.",
      tags: ["memory", "literature", "culture"],
      author: "Sven Olsson"
    },
    %{
      title:
        "Narrative Entropy: Chaos Theory and Structure in Modernist Fiction",
      summary:
        "Applies principles from chaos theory to explain the apparent disorder and hidden patterning in selected modernist novels.",
      tags: ["literature", "modernism", "theory"],
      author: "Sven Olsson"
    },
    %{
      title:
        "Soundscapes of Faith: Acoustic Analysis of Medieval Cathedral Chant",
      summary:
        "Combines acoustic modeling and musicology to reconstruct the sonic environment of medieval chant within cathedral spaces.",
      tags: ["music", "religion", "history"],
      author: "Jean-Marie Leclerc"
    },
    %{
      title:
        "Datafied Memory: Digital Humanities Approaches to Holocaust Testimony Archives",
      summary:
        "Explores computational methods for indexing, visualizing, and analyzing large-scale Holocaust testimony datasets.",
      tags: ["digital-humanities", "memory", "archives"],
      author: "Jean-Marie Leclerc"
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
    article_count = Keyword.get(opts, :article_count)

    Enum.each(@tags, fn name ->
      insert(%Tag{name: name})
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
      content: article_data.summary,
      publish_date:
        DateTime.utc_now()
        |> DateTime.add(-1 * :rand.uniform(20), :day)
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

  # def with_author_role(%Author{id: author_id} = author) when not is_nil(author_id) do
  #   insert(%Role{
  #     name: sequence(:role_name, @roles),
  #     author: author
  #   })
  # end

  def article_data_factory do
    sequence(:article_data, @articles)
  end

  def author_name_factory do
    sequence(:author_name, @authors)
  end
end
