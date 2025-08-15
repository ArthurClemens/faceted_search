defmodule FacetedSearch.Test.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: FacetedSearch.Test.Repo

  alias FacetedSearch.Test.MyApp.Article

  @titles_and_summaries [
    %{
      title:
        "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises",
      summary:
        "Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood.",
      draft: true
    },
    %{
      title:
        "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
      summary:
        "Analyzes the layered temporal structures present in oral testimonies from post-war societies, integrating insights from history, psychology, and narratology.",
      draft: false
    },
    %{
      title:
        "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
      summary:
        "Explores how symbolic motifs circulated through manuscript production, illuminating networks of cultural exchange in medieval Europe.",
      draft: true
    },
    %{
      title:
        "The Grammar of Resistance: Syntax and Subversion in 20th-Century Protest Literature",
      summary:
        "Investigates how unconventional syntax and grammar functioned as tools of political resistance in literary works tied to protest movements.",
      draft: false
    },
    %{
      title:
        "Ritual as Algorithm: Pattern Recognition in Indigenous Performance Practices",
      summary:
        "Identifies recurring formal patterns in Indigenous rituals and compares them to algorithmic structures, offering a computational perspective on performance.",
      draft: true
    },
    %{
      title:
        "Emotional Cartography: Mapping Affective Landscapes in Victorian Travel Writing",
      summary:
        "Charts the representation of emotions in Victorian travel narratives to show how writers spatialized feelings in relation to foreign landscapes.",
      draft: false
    },
    %{
      title:
        "From Papyrus to Pixel: Materiality and Meaning in the Evolution of the Book",
      summary:
        "Traces the transformation of the book as a material and symbolic object from antiquity to the digital age, emphasizing shifts in reading practices.",
      draft: false
    },
    %{
      title: "Spectral Agency: Ghost Narratives as Cultural Memory Archives",
      summary:
        "Considers ghost stories as repositories of collective memory, revealing their role in preserving suppressed or marginalized histories.",
      draft: false
    },
    %{
      title: "Interpreting Silence: Nonverbal Communication in Early Cinema",
      summary:
        "Analyzes gesture, facial expression, and mise-en-scène in silent films to uncover visual grammars of meaning-making before synchronized sound.",
      draft: false
    },
    %{
      title:
        "Narrative Entropy: Chaos Theory and Structure in Modernist Fiction",
      summary:
        "Applies principles from chaos theory to explain the apparent disorder and hidden patterning in selected modernist novels.",
      draft: false
    }
  ]

  def article_factory do
    title_and_summary = build(:title_and_summary)

    %Article{
      title: title_and_summary.title,
      content: title_and_summary.summary,
      draft: title_and_summary.draft,
      publish_date:
        DateTime.utc_now()
        |> DateTime.add(-1 * :rand.uniform(20), :day)
        |> DateTime.to_naive()
    }
  end

  def title_and_summary_factory do
    sequence(:title_and_summary, @titles_and_summaries)
  end
end
