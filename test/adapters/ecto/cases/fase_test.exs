defmodule Fase.Test.Adapters.Ecto.FaseTest do
  use Fase.Test.Integration.Case

  import Ecto.Query
  import Fase.Test.Factory

  alias Fase.Test.MyApp.ExtendedFacetSchema
  alias Fase.Test.MyApp.MultipleSourcesFacetSchema
  alias Fase.Test.MyApp.PrefixFacetSchema
  alias Fase.Test.MyApp.ScopedFacetSchema
  alias Fase.Test.MyApp.TimestampsFacetSchema
  alias Fase.Test.MyApp.TransformsFacetSchema
  alias Fase.Test.MyApp.UUIDFacetSchema
  alias Fase.Test.Repo

  setup_all do
    on_exit(fn ->
      [
        ExtendedFacetSchema,
        MultipleSourcesFacetSchema,
        PrefixFacetSchema,
        ScopedFacetSchema,
        TimestampsFacetSchema,
        TransformsFacetSchema
      ]
      |> Enum.each(&Fase.drop_search_view(&1, "articles"))
    end)
  end

  describe "search view" do
    setup do
      init_resources(article_count: 2)

      :ok
    end

    test "the create_search_view/3 function" do
      expected = {:ok, "articles"}

      assert Fase.create_search_view(ExtendedFacetSchema, "articles") ==
               expected
    end

    test "the search_view_exists?/3 function" do
      expected = false

      assert Fase.search_view_exists?(ExtendedFacetSchema, "articles") ==
               expected

      Fase.create_search_view(ExtendedFacetSchema, "articles")

      expected = true

      assert Fase.search_view_exists?(ExtendedFacetSchema, "articles") ==
               expected
    end

    test "the create_search_view_if_not_exists/3 function" do
      expected = false

      assert Fase.search_view_exists?(ExtendedFacetSchema, "articles") ==
               expected

      Fase.create_search_view_if_not_exists(
        ExtendedFacetSchema,
        "articles"
      )

      expected = true

      assert Fase.search_view_exists?(ExtendedFacetSchema, "articles") ==
               expected
    end

    test "the refresh_search_view/3 function" do
      # Initial view has 2 items
      Fase.create_search_view(ExtendedFacetSchema, "articles")

      results = search_all("articles", ExtendedFacetSchema)
      expected = 2
      assert Enum.count(results) == expected

      # Add 3 more items and refresh the view
      build_list(3, :insert_article)
      Fase.refresh_search_view(ExtendedFacetSchema, "articles")
      results = search_all("articles", ExtendedFacetSchema)
      expected = 5
      assert Enum.count(results) == expected
    end

    test "the drop_search_view/3 function" do
      # Initial view has 2 items
      Fase.create_search_view(ExtendedFacetSchema, "articles")

      expected = true

      assert Fase.search_view_exists?(ExtendedFacetSchema, "articles") ==
               expected

      Fase.drop_search_view(ExtendedFacetSchema, "articles")
      expected = false

      assert Fase.search_view_exists?(ExtendedFacetSchema, "articles") ==
               expected
    end
  end

  describe "filtering: text search" do
    setup do
      init_resources(article_count: 10)

      Fase.create_search_view(ExtendedFacetSchema, "articles")
      :ok
    end

    test "text field result" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "metaphors"}]
      }

      expected = [
        "Hélène Dubois Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood."
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert results |> Enum.map(& &1.text) == expected
    end

    test "text field result (text with accents: without unaccent operation will not find a match)" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "Helene"}]
      }

      expected = []

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert results |> Enum.map(& &1.text) == expected
    end

    test "single term" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "political"}]
      }

      expected = 2

      {:ok, {_results, meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "multiple terms" do
      search_params = %{
        filters: [
          %{field: :text, op: :ilike, value: "political"},
          %{field: :text, op: :ilike, value: "metaphors"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "multiple terms using ilike_and" do
      search_params = %{
        filters: [
          %{field: :text, op: :ilike_and, value: "political metaphors"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert meta.total_count == expected
    end
  end

  describe "filtering: data fields" do
    setup do
      init_resources(article_count: 10)

      Fase.create_search_view(ExtendedFacetSchema, "articles")
      :ok
    end

    test "data field result (including casts of field 'draft' and 'word_count')" do
      search_params = %{
        filters: [
          %{field: :title, op: :ilike, value: "politiques"}
        ]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      expected = [
        %{
          "id" => "uuid",
          "author" => "Hélène Dubois",
          "draft" => 1,
          "indicators" => %{
            "type" => [
              "history",
              "language_analysis",
              "politics"
            ],
            "word_count" => "3473",
            "draft" => true
          },
          "tag_titles" => [
            "History",
            "Language analysis: Critical reading",
            "Politics"
          ],
          "tags" => [
            "history",
            "language_analysis",
            "politics"
          ],
          "title" =>
            "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne"
        }
      ]

      assert results
             |> Enum.map(fn %{data: data} ->
               data
               |> Map.replace("publish_date", "datetime")
               |> Map.replace("id", "uuid")
             end) == expected
    end

    test "search subfield: title (ilike)" do
      search_params = %{
        filters: [
          %{field: :title, op: :ilike, value: "politiques"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "search subfield: author" do
      search_params = %{
        filters: [
          %{field: :author, op: :==, value: "Mateo Alvarez"}
        ]
      }

      expected = 2

      {:ok, {_results, meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "search subfield: tag_titles" do
      search_params = %{
        filters: [
          %{field: :tag_titles, op: :==, value: ["History"]}
        ]
      }

      expected = [
        ["Books", "History", "Materiality"],
        ["History", "Language analysis: Critical reading", "Politics"],
        ["History", "Manuscripts", "Semiotics"],
        ["History", "Music", "Religion"]
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert get_in(results, [Access.all(), Access.key(:data), "tag_titles"])
             |> Enum.sort() ==
               expected
    end

    test "search subfield: tag_titles (multiple)" do
      search_params = %{
        filters: [
          %{
            field: :tag_titles,
            op: :==,
            value: ["Literature", "Language analysis: Critical reading"]
          }
        ]
      }

      expected = [
        ["Language analysis: Critical reading", "Literature", "Politics"]
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert get_in(results, [Access.all(), Access.key(:data), "tag_titles"]) ==
               expected
    end

    test "search on cast value" do
      search_params = %{
        filters: [
          %{
            field: :draft,
            op: :==,
            value: 1
          }
        ]
      }

      expected = [
        %{
          "draft" => 1,
          "title" =>
            "From Papyrus to Pixel: Materiality and Meaning in the Evolution of the Book"
        },
        %{
          "draft" => 1,
          "title" =>
            "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne"
        },
        %{
          "draft" => 1,
          "title" =>
            "Soundscapes of Faith: Acoustic Analysis of Medieval Cathedral Chant"
        },
        %{
          "draft" => 1,
          "title" =>
            "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      assert get_in(results, [Access.all(), Access.key(:data)])
             |> Enum.map(&Map.take(&1, ["title", "draft"]))
             |> Enum.sort() ==
               expected
    end
  end

  describe "sorting" do
    setup do
      init_resources(article_count: 10)
      Fase.create_search_view(ExtendedFacetSchema, "articles")
      :ok
    end

    test "sorting by default_order" do
      search_params = %{}

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      entries =
        Enum.map(
          results,
          &%{publish_date: &1.sort_publish_date, author: &1.sort_author}
        )

      expected =
        Enum.sort_by(
          entries,
          &{&1.publish_date, &1.author},
          &compare_default_order_results/2
        )

      assert entries == expected
    end

    defp compare_default_order_results(
           {publish_date_a, author_a},
           {publish_date_b, author_b}
         ) do
      case Date.compare(publish_date_a, publish_date_b) do
        :eq -> String.downcase(author_a) < String.downcase(author_b)
        :gt -> true
        _ -> false
      end
    end

    test "sorting on publish_date (datetime)" do
      search_params = %{
        order_by: [:sort_publish_date],
        order_directions: [:desc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      entries = Enum.map(results, & &1.sort_publish_date)
      expected = Enum.sort(entries, {:desc, DateTime})
      assert entries == expected
    end

    test "sorting on author (string)" do
      search_params = %{
        order_by: [:sort_author],
        order_directions: [:asc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      entries = Enum.map(results, & &1.sort_author)
      expected = Enum.sort(entries, :asc)
      assert entries == expected
    end

    test "sorting with multiple order directions" do
      search_params = %{
        order_by: [:sort_author, :sort_publish_date],
        order_directions: [:asc, :desc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", ExtendedFacetSchema, search_params)

      entries = Enum.map(results, &{&1.sort_author, &1.sort_publish_date})

      expected =
        Enum.sort_by(results, &{!&1.sort_author, !&1.sort_publish_date})
        |> Enum.map(&{&1.sort_author, &1.sort_publish_date})

      assert entries == expected
    end
  end

  describe "facets" do
    setup do
      init_resources(article_count: 10)
      Fase.create_search_view(ExtendedFacetSchema, "articles")

      :ok
    end

    test "facet results (no search params)" do
      search_params = %{}

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params,
          scope: %{locale: "fr"}
        )

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "archives",
              selected: false,
              value: "archives"
            },
            %Fase.Option{
              count: 1,
              label: "books",
              selected: false,
              value: "books"
            }
          ]
        },
        publish_date: %{
          count: 4,
          first_2_options: [
            %Fase.Option{
              count: 4,
              label: "last year",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 1,
              label: "last quarter",
              selected: false,
              value: 2
            }
          ]
        },
        tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Archives",
              selected: false,
              value: "archives"
            },
            %Fase.Option{
              count: 1,
              label: "Books",
              selected: false,
              value: "books"
            }
          ]
        },
        word_count: %{
          count: 3,
          first_2_options: [
            %Fase.Option{
              count: 5,
              label: "de 2000 à 4000",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 2,
              label: "de 4000 à 6000",
              selected: false,
              value: 2
            }
          ]
        }
      }

      assert meta.total_count == 10
      assert facet_result_subset(facets) == expected
    end

    test "search facets (single facet)" do
      search_params = %{
        filters: [
          %{
            value: ["Aisha Rahman", "Jean-Marie Leclerc"],
            op: :==,
            field: :facet_author
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: true
            },
            %Fase.Option{
              value: "Hélène Dubois",
              label: "Hélène Dubois",
              count: 2,
              selected: false
            }
          ]
        },
        tags: %{
          count: 11,
          first_2_options: [
            %Fase.Option{
              value: "archives",
              label: "Archives",
              count: 1,
              selected: false
            },
            %Fase.Option{
              value: "books",
              label: "Books",
              count: 1,
              selected: false
            }
          ]
        },
        word_count: %{
          count: 2,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "2000-4000",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 2,
              label: "6000-8000",
              selected: false,
              value: 3
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: false
            },
            %Fase.Option{
              value: "Hélène Dubois",
              label: "Hélène Dubois",
              count: 2,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %Fase.Option{
              value: "books",
              label: "books",
              count: 1,
              selected: false
            }
          ]
        },
        publish_date: %{
          count: 2,
          first_2_options: [
            %Fase.Option{
              count: 3,
              label: "last year",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 1,
              label: "last month",
              selected: false,
              value: 3
            }
          ]
        }
      }

      assert meta.total_count == 4
      assert facet_result_subset(facets) == expected
    end

    test "search facets (multiple facets)" do
      search_params = %{
        filters: [
          %{
            value: ["Aisha Rahman"],
            op: :==,
            field: :facet_author
          },
          %{
            value: ["history"],
            op: :==,
            field: :facet_tags
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 1,
              selected: true
            },
            %Fase.Option{
              value: "Hélène Dubois",
              label: "Hélène Dubois",
              count: 2,
              selected: false
            }
          ]
        },
        tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              value: "archives",
              label: "Archives",
              count: 1,
              selected: false
            },
            %Fase.Option{
              value: "books",
              label: "Books",
              count: 1,
              selected: false
            }
          ]
        },
        word_count: %{
          count: 1,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "2000-4000",
              selected: false,
              value: 1
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 1,
              selected: false
            },
            %Fase.Option{
              value: "Hélène Dubois",
              label: "Hélène Dubois",
              count: 2,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %Fase.Option{
              value: "books",
              label: "books",
              count: 1,
              selected: false
            }
          ]
        },
        publish_date: %{
          count: 1,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "last year",
              selected: false,
              value: 1
            }
          ]
        }
      }

      assert meta.total_count == 1
      assert facet_result_subset(facets) == expected
    end

    test "search facets: number_range_bounds" do
      search_params = %{
        filters: [
          %{
            value: [1, 2],
            op: :==,
            field: :facet_word_count
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "archives",
              selected: false,
              value: "archives"
            },
            %Fase.Option{
              count: 1,
              label: "books",
              selected: false,
              value: "books"
            }
          ]
        },
        publish_date: %{
          count: 3,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "last year",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 3,
              label: "last month",
              selected: false,
              value: 3
            }
          ]
        },
        tags: %{
          count: 14,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Books",
              selected: false,
              value: "books"
            },
            %Fase.Option{
              count: 1,
              label: "Culture",
              selected: false,
              value: "culture"
            }
          ]
        },
        word_count: %{
          count: 3,
          first_2_options: [
            %Fase.Option{
              count: 5,
              label: "2000-4000",
              selected: true,
              value: 1
            },
            %Fase.Option{
              count: 2,
              label: "4000-6000",
              selected: true,
              value: 2
            }
          ]
        }
      }

      assert meta.total_count == 7
      assert facet_result_subset(facets) == expected

      expected_publish_date_options = [
        %Fase.Option{
          count: 2,
          label: "last year",
          selected: false,
          value: 1
        },
        %Fase.Option{
          count: 3,
          label: "last month",
          selected: false,
          value: 3
        },
        %Fase.Option{
          count: 2,
          label: "today",
          value: 5,
          selected: false
        }
      ]

      assert Enum.find(facets, &(&1.field == :publish_date))
             |> get_in([Access.key(:options)]) == expected_publish_date_options
    end

    test "search facets: date_range_bounds" do
      search_params = %{
        filters: [
          %{
            value: [3, 4],
            op: :==,
            field: :facet_publish_date
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 3,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Jean-Marie Leclerc",
              selected: false,
              value: "Jean-Marie Leclerc"
            },
            %Fase.Option{
              count: 1,
              label: "Mateo Alvarez",
              selected: false,
              value: "Mateo Alvarez"
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "archives",
              selected: false,
              value: "archives"
            },
            %Fase.Option{
              count: 1,
              label: "books",
              selected: false,
              value: "books"
            }
          ]
        },
        publish_date: %{
          count: 4,
          first_2_options: [
            %Fase.Option{
              count: 4,
              label: "last year",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 1,
              label: "last quarter",
              selected: false,
              value: 2
            }
          ]
        },
        tags: %{
          count: 8,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Culture",
              selected: false,
              value: "culture"
            },
            %Fase.Option{
              count: 2,
              label: "History",
              selected: false,
              value: "history"
            }
          ]
        },
        word_count: %{
          count: 2,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "2000-4000",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 2,
              label: "4000-6000",
              selected: false,
              value: 2
            }
          ]
        }
      }

      assert meta.total_count == 3
      assert facet_result_subset(facets) == expected

      expected_publish_date_options = [
        %Fase.Option{
          count: 4,
          label: "last year",
          selected: false,
          value: 1
        },
        %Fase.Option{
          count: 1,
          label: "last quarter",
          selected: false,
          value: 2
        },
        %Fase.Option{
          count: 3,
          label: "last month",
          selected: true,
          value: 3
        },
        %Fase.Option{
          count: 2,
          label: "today",
          selected: false,
          value: 5
        }
      ]

      assert Enum.find(facets, &(&1.field == :publish_date))
             |> get_in([Access.key(:options)]) == expected_publish_date_options
    end

    test "search facets: hierarchies (level 1)" do
      search_params = %{
        filters: [
          %{
            value: ["Aisha Rahman", "Hélène Dubois"],
            op: :==,
            field: :facet_category_author
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 2,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: true,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 2,
              label: "Hélène Dubois",
              selected: true,
              value: "Hélène Dubois"
            }
          ]
        },
        category_author_tags: %{
          count: 12,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Aisha Rahman>books",
              selected: false,
              value: "Aisha Rahman>books"
            },
            %Fase.Option{
              count: 1,
              label: "Aisha Rahman>emotion",
              selected: false,
              value: "Aisha Rahman>emotion"
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "archives",
              selected: false,
              value: "archives"
            },
            %Fase.Option{
              count: 1,
              label: "books",
              selected: false,
              value: "books"
            }
          ]
        },
        publish_date: %{
          count: 2,
          first_2_options: [
            %Fase.Option{
              count: 3,
              label: "last year",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 1,
              label: "today",
              selected: false,
              value: 5
            }
          ]
        },
        tags: %{
          count: 11,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Books",
              selected: false,
              value: "books"
            },
            %Fase.Option{
              count: 1,
              label: "Emotion",
              selected: false,
              value: "emotion"
            }
          ]
        },
        word_count: %{
          count: 2,
          first_2_options: [
            %Fase.Option{
              count: 3,
              label: "2000-4000",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 1,
              label: "6000-8000",
              selected: false,
              value: 3
            }
          ]
        }
      }

      assert meta.total_count == 4
      assert facet_result_subset(facets) == expected
    end

    test "search facets: hierarchies (level 2)" do
      search_params = %{
        filters: [
          %{
            value: ["Hélène Dubois>history"],
            op: :==,
            field: :facet_category_author_tags
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 1,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Hélène Dubois",
              selected: false,
              value: "Hélène Dubois"
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %Fase.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %Fase.Option{
              count: 1,
              label: "Hélène Dubois",
              selected: true,
              value: "Hélène Dubois"
            }
          ]
        },
        category_author_tags: %{
          count: 6,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Hélène Dubois>history",
              selected: true,
              value: "Hélène Dubois>history"
            },
            %Fase.Option{
              count: 1,
              label: "Hélène Dubois>interdisciplinary",
              selected: false,
              value: "Hélène Dubois>interdisciplinary"
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "archives",
              selected: false,
              value: "archives"
            },
            %Fase.Option{
              count: 1,
              label: "books",
              selected: false,
              value: "books"
            }
          ]
        },
        publish_date: %{
          count: 1,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "last year",
              selected: false,
              value: 1
            }
          ]
        },
        tags: %{
          count: 3,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "History",
              selected: false,
              value: "history"
            },
            %Fase.Option{
              count: 1,
              label: "Language analysis: Critical reading",
              selected: false,
              value: "language_analysis"
            }
          ]
        },
        word_count: %{
          count: 1,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "2000-4000",
              selected: false,
              value: 1
            }
          ]
        }
      }

      assert meta.total_count == 1
      assert facet_result_subset(facets) == expected
    end
  end

  describe "transforms" do
    setup do
      articles = init_resources(article_count: 5, insert_delay: 500)
      Fase.create_search_view(TransformsFacetSchema, "articles")

      %{articles: articles}
    end

    test "text field result (text with accents: with operation 'unaccent' will find a match; includes transforms 'to_date', 'initcap', 'concat' and 'length')" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "Helene"}]
      }

      expected = [
        "Analyzes the layered temporal structures present in oral testimonies from post-war societies, integrating insights from history, psychology, and narratology. Temporalities Of Memory: An Interdisciplinary Approach To Post-War Oral Histories 81 Helene Dubois date 0",
        "Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood. Géographie Des Marges : Métaphores Spatiales Dans Les Traités Politiques À L'Époque Moderne 91 Helene Dubois date 0"
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params)

      assert results
             |> Enum.map(& &1.text)
             |> Enum.map(&String.replace(&1, ~r/(\d{4}-\d{2}-\d{2})/, "date"))
             |> Enum.sort() == expected
    end

    test "text field search with accent in the query value" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "Hélène"}]
      }

      expected = [
        "Analyzes the layered temporal structures present in oral testimonies from post-war societies, integrating insights from history, psychology, and narratology. Temporalities Of Memory: An Interdisciplinary Approach To Post-War Oral Histories 81 Helene Dubois date 0",
        "Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood. Géographie Des Marges : Métaphores Spatiales Dans Les Traités Politiques À L'Époque Moderne 91 Helene Dubois date 0"
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params)

      assert results
             |> Enum.map(& &1.text)
             |> Enum.map(&String.replace(&1, ~r/(\d{4}-\d{2}-\d{2})/, "date"))
             |> Enum.sort() == expected
    end

    test "data field result (search data.publish_date)", context do
      %{articles: articles} = context

      first_article_publish_date =
        articles
        |> Enum.map(&Map.from_struct(&1))
        |> Enum.sort_by(
          & &1.publish_date,
          {:desc, DateTime}
        )
        |> List.first()
        |> Map.get(:publish_date)
        |> Calendar.strftime("%Y-%m-%d")

      search_params = %{
        filters: [
          %{field: :publish_date, op: :==, value: first_article_publish_date}
        ]
      }

      expected = [
        %{
          "author" => "Hélène Dubois",
          "indicators" => %{"word_count" => "2871"},
          "publish_date" => "publish_date",
          "title" =>
            "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
          "inserted_at" => "inserted_at"
        },
        %{
          "author" => "Mateo Alvarez",
          "indicators" => %{"word_count" => "3627"},
          "publish_date" => "publish_date",
          "title" =>
            "The Grammar of Resistance: Syntax and Subversion in 20th-Century Protest Literature",
          "inserted_at" => "inserted_at"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params)

      assert results
             |> Enum.map(
               &(&1.data
                 |> Map.replace("publish_date", "publish_date")
                 |> Map.replace("inserted_at", "inserted_at"))
             )
             |> Enum.sort_by(& &1["title"]) ==
               expected
    end

    test "data field search (search data.author, without accent in the query value) (uses callback search_transform/3)" do
      search_params = %{
        filters: [%{field: :author, op: :ilike, value: "Dubois Helene"}]
      }

      expected = [
        %{
          "author" => "Hélène Dubois",
          "indicators" => %{"word_count" => "3473"},
          "publish_date" => "publish_date",
          "title" =>
            "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne",
          "inserted_at" => "inserted_at"
        },
        %{
          "author" => "Hélène Dubois",
          "indicators" => %{"word_count" => "2871"},
          "publish_date" => "publish_date",
          "title" =>
            "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
          "inserted_at" => "inserted_at"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params)

      assert results
             |> Enum.map(
               &(&1.data
                 |> Map.replace("publish_date", "publish_date")
                 |> Map.replace("inserted_at", "inserted_at"))
             )
             |> Enum.sort_by(& &1["title"]) ==
               expected
    end

    test "sorting on publish_date (cast to integer)" do
      search_params = %{
        order_by: [:sort_publish_date],
        order_directions: [:desc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params)

      entries = Enum.map(results, & &1.sort_publish_date)
      expected = Enum.sort(entries, :desc)
      assert entries == expected
    end

    test "filter search with search_condition callback (author)" do
      search_params = %{
        filters: [%{field: :author, value: "Matt"}]
      }

      expected = ["Mateo Alvarez"]

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params)

      assert results |> Enum.map(& &1.data["author"]) |> Enum.uniq() == expected
    end

    test "filter search with search_condition callback (inserted_at)" do
      search_params = %{
        filters: [
          %{field: :inserted_at, op: :<=, value: offset_now(-2, :second)}
        ]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", TransformsFacetSchema, search_params,
          extra_opts: [timezone: "Etc/UTC"]
        )

      count = Enum.count(results)
      assert count > 0 and count < 5
    end
  end

  describe "scope (word_count)" do
    setup do
      init_resources(article_count: 10)

      Fase.create_search_view(ScopedFacetSchema, "articles",
        scope: %{word_count: 4000}
      )

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = [4898, 5591, 6131, 6581, 7643]

      {:ok, {results, _meta}} =
        filtered_search("articles", ScopedFacetSchema, search_params)

      assert results |> Enum.map(& &1.data["word_count"]) |> Enum.sort() ==
               expected
    end
  end

  describe "scope (publish_date)" do
    setup do
      articles = init_resources(article_count: 10)

      last_month = offset_now(-30)

      Fase.create_search_view(ScopedFacetSchema, "articles",
        scope: %{publish_date: last_month}
      )

      %{articles: articles}
    end

    test "results without filters", context do
      %{articles: articles} = context
      search_params = %{}

      first_article_publish_date =
        articles
        |> Enum.map(&Map.from_struct(&1))
        |> Enum.sort_by(
          & &1.publish_date,
          {:desc, DateTime}
        )
        |> List.first()
        |> Map.get(:publish_date)

      date_1 = first_article_publish_date
      date_2 = offset_datetime(date_1, -9)

      expected = [
        date_1,
        date_1,
        date_2,
        date_2,
        date_2
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ScopedFacetSchema, search_params)

      assert results
             |> Enum.map(fn result ->
               {:ok, datetime, _} =
                 DateTime.from_iso8601(result.data["publish_date"] <> "Z")

               datetime
             end)
             |> Enum.sort({:desc, DateTime}) == expected
    end
  end

  describe "scope (combined word_count and publish_date)" do
    setup do
      init_resources(article_count: 10)

      last_month = now() |> DateTime.add(-30, :day)

      Fase.create_search_view(ScopedFacetSchema, "articles",
        scope: %{word_count: 4000, publish_date: last_month}
      )

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        %{
          "publish_date" => "date",
          "title" =>
            "Spectral Agency: Ghost Narratives as Cultural Memory Archives",
          "word_count" => 4898
        },
        %{
          "publish_date" => "date",
          "title" =>
            "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
          "word_count" => 5591
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ScopedFacetSchema, search_params)

      assert results
             |> Enum.map(
               &Map.replace(
                 &1.data,
                 "publish_date",
                 "date"
               )
             )
             |> Enum.sort_by(& &1["word_count"]) ==
               expected
    end
  end

  describe "multiple sources schema" do
    setup do
      init_resources(article_count: 10)

      Fase.create_search_view(MultipleSourcesFacetSchema, "articles")

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        "articles",
        "articles",
        "articles",
        "articles",
        "articles",
        "articles",
        "articles",
        "articles",
        "articles",
        "articles",
        "authors",
        "authors",
        "authors",
        "authors",
        "authors"
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params,
          page_size: 100
        )

      assert results |> Enum.map(& &1.source) |> Enum.sort() == expected
    end

    test "filter on source column (authors)" do
      search_params = %{
        filters: [
          %{field: :source, op: :==, value: "authors"}
        ]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.all?(&(&1.source == "authors"))
    end

    test "filter on shared data field (author)" do
      search_params = %{
        filters: [
          %{field: :author, op: :==, value: "Hélène Dubois"}
        ]
      }

      expected = [
        %{
          data: %{
            "author" => "Hélène Dubois",
            "birthdate" => "1977-01-25",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Hélène Dubois",
            "publish_date" => "date",
            "title" =>
              "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne"
          },
          source: "articles"
        },
        %{
          data: %{
            "author" => "Hélène Dubois",
            "publish_date" => "date",
            "title" =>
              "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories"
          },
          source: "articles"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.map(
               &%{
                 source: &1.source,
                 data: &1.data |> Map.replace("publish_date", "date")
               }
             )
             |> Enum.sort() == expected
    end

    test "filter on shared data field (source)" do
      search_params = %{
        filters: [
          %{field: :source, op: :==, value: "authors"}
        ]
      }

      expected = [
        %{
          data: %{
            "author" => "Aisha Rahman",
            "birthdate" => "1967-10-22",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Hélène Dubois",
            "birthdate" => "1977-01-25",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Jean-Marie Leclerc",
            "birthdate" => "1985-12-01",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Mateo Alvarez",
            "birthdate" => "1998-06-02",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Sven Olsson",
            "birthdate" => "1947-10-22",
            "source" => "authors"
          },
          source: "authors"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.map(&%{source: &1.source, data: &1.data})
             |> Enum.sort() == expected
    end

    test "filter on shared text field (source)" do
      search_params = %{
        filters: [
          %{field: :text, op: :ilike_and, value: "authors Sven Olsson"}
        ]
      }

      expected = ["Sven Olsson 1947-10-22 authors"]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.map(& &1.text)
             |> Enum.sort() == expected
    end

    test "sort on field from 1 source" do
      search_params =
        %{
          order_by: [:sort_birthdate],
          order_directions: [:asc]
        }

      expected = [
        %{
          data: %{
            "author" => "Sven Olsson",
            "birthdate" => "1947-10-22",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Aisha Rahman",
            "birthdate" => "1967-10-22",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Hélène Dubois",
            "birthdate" => "1977-01-25",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Jean-Marie Leclerc",
            "birthdate" => "1985-12-01",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Mateo Alvarez",
            "birthdate" => "1998-06-02",
            "source" => "authors"
          },
          source: "authors"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params,
          page_size: 100
        )

      assert results
             |> Enum.map(&%{source: &1.source, data: &1.data})
             |> Enum.filter(&(&1.source == "authors")) == expected
    end

    test "sort on shared column (source)" do
      search_params = %{
        order_by: [:sort_source, :sort_author],
        order_directions: [:asc]
      }

      expected = [
        %{
          sort_author: "Aisha Rahman",
          sort_source: "articles"
        },
        %{
          sort_author: "Hélène Dubois",
          sort_source: "articles"
        },
        %{
          sort_author: "Jean-Marie Leclerc",
          sort_source: "articles"
        },
        %{
          sort_author: "Mateo Alvarez",
          sort_source: "articles"
        },
        %{sort_author: "Sven Olsson", sort_source: "articles"},
        %{sort_author: "Aisha Rahman", sort_source: "authors"},
        %{
          sort_author: "Hélène Dubois",
          sort_source: "authors"
        },
        %{
          sort_author: "Jean-Marie Leclerc",
          sort_source: "authors"
        },
        %{
          sort_author: "Mateo Alvarez",
          sort_source: "authors"
        },
        %{sort_author: "Sven Olsson", sort_source: "authors"}
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params,
          page_size: 20
        )

      assert results
             |> Enum.map(
               &%{sort_source: &1.sort_source, sort_author: &1.sort_author}
             )
             |> Enum.uniq() ==
               expected
    end

    test "facet search" do
      search_params = %{
        filters: [
          %{field: :facet_author, op: :==, value: ["Hélène Dubois"]}
        ]
      }

      expected = [
        %{
          data: %{
            "author" => "Hélène Dubois",
            "birthdate" => "1977-01-25",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Hélène Dubois",
            "publish_date" => "date",
            "title" =>
              "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne"
          },
          source: "articles"
        },
        %{
          data: %{
            "author" => "Hélène Dubois",
            "publish_date" => "date",
            "title" =>
              "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories"
          },
          source: "articles"
        }
      ]

      {:ok, {results, _meta}, facets} =
        facet_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.map(
               &%{
                 source: &1.source,
                 data: &1.data |> Map.replace("publish_date", "date")
               }
             )
             |> Enum.sort() == expected

      expected_source_options = [
        %Fase.Option{
          value: "articles",
          label: "articles",
          count: 2,
          selected: false
        },
        %Fase.Option{
          value: "authors",
          label: "authors",
          count: 1,
          selected: false
        }
      ]

      assert Enum.find(facets, &(&1.field == :source))
             |> get_in([Access.key(:options)]) == expected_source_options
    end

    test "search facets: date_range_bounds (only 1 of the sources has this specified)" do
      search_params = %{
        filters: [
          %{
            value: [3, 4],
            op: :==,
            field: :facet_publish_date
          }
        ]
      }

      {:ok, {results, meta}, facets} =
        facet_search("articles", ExtendedFacetSchema, search_params)

      assert meta.total_count == 3

      expected_results = [
        %{
          source: "articles",
          title:
            "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture"
        },
        %{
          source: "articles",
          title:
            "Soundscapes of Faith: Acoustic Analysis of Medieval Cathedral Chant"
        },
        %{
          source: "articles",
          title: "Spectral Agency: Ghost Narratives as Cultural Memory Archives"
        }
      ]

      assert results
             |> Enum.map(&%{source: &1.source, title: &1.data["title"]})
             |> Enum.sort() ==
               expected_results

      expected_facets = %{
        author: %{
          count: 3,
          first_2_options: [
            %Fase.Option{
              count: 1,
              label: "Jean-Marie Leclerc",
              selected: false,
              value: "Jean-Marie Leclerc"
            },
            %Fase.Option{
              count: 1,
              label: "Mateo Alvarez",
              value: "Mateo Alvarez",
              selected: false
            }
          ]
        },
        publish_date: %{
          count: 4,
          first_2_options: [
            %Fase.Option{
              count: 4,
              label: "last year",
              selected: false,
              value: 1
            },
            %Fase.Option{
              count: 1,
              label: "last quarter",
              selected: false,
              value: 2
            }
          ]
        }
      }

      assert facet_result_subset(facets) == expected_facets

      expected_publish_date_options = [
        %Fase.Option{
          count: 4,
          label: "last year",
          selected: false,
          value: 1
        },
        %Fase.Option{
          count: 1,
          label: "last quarter",
          selected: false,
          value: 2
        },
        %Fase.Option{
          count: 3,
          label: "last month",
          selected: true,
          value: 3
        },
        %Fase.Option{
          count: 2,
          label: "today",
          selected: false,
          value: 5
        }
      ]

      assert Enum.find(facets, &(&1.field == :publish_date))
             |> get_in([Access.key(:options)]) == expected_publish_date_options
    end
  end

  describe "scope with sources" do
    setup do
      init_resources(article_count: 10)

      Fase.create_search_view(MultipleSourcesFacetSchema, "articles",
        scope: %{source: "authors"}
      )

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = ["authors", "authors", "authors", "authors", "authors"]

      {:ok, {results, _meta}} =
        filtered_search("articles", ScopedFacetSchema, search_params)

      assert results |> Enum.map(& &1.source) ==
               expected
    end
  end

  describe "prefixes" do
    setup do
      init_resources(article_count: 10)

      Fase.create_search_view(PrefixFacetSchema, "articles",
        prefix: "classifications"
      )

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        %{
          "article_title" =>
            "Datafied Memory: Digital Humanities Approaches to Holocaust Testimony Archives, The Grammar of Resistance: Syntax and Subversion in 20th-Century Protest Literature",
          "category_name" => "editorial"
        },
        %{
          "article_title" =>
            "Emotional Cartography: Mapping Affective Landscapes in Victorian Travel Writing, Soundscapes of Faith: Acoustic Analysis of Medieval Cathedral Chant, Spectral Agency: Ghost Narratives as Cultural Memory Archives",
          "category_name" => "review"
        },
        %{
          "article_title" =>
            "From Papyrus to Pixel: Materiality and Meaning in the Evolution of the Book, Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne, Narrative Entropy: Chaos Theory and Structure in Modernist Fiction, Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture, Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
          "category_name" => "paper"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", PrefixFacetSchema, search_params,
          page_size: 100,
          query_opts: [prefix: "classifications"]
        )

      assert results
             |> Enum.map(& &1.data)
             |> Enum.sort() == expected
    end
  end

  describe "filtering and sorting on timestamps" do
    setup do
      articles = init_resources(article_count: 3, insert_delay: 1_000)

      Fase.create_search_view(TimestampsFacetSchema, "articles",
        scope: %{source: "authors"}
      )

      %{articles: articles}
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
          "updated_at" => "timestamp"
        },
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
          "updated_at" => "timestamp"
        },
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne",
          "updated_at" => "timestamp"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", TimestampsFacetSchema, search_params)

      assert results
             |> Enum.map(fn %{data: data} ->
               {:ok, updated_at, _} =
                 DateTime.from_iso8601(data["updated_at"] <> "Z")

               {:ok, inserted_at, _} =
                 DateTime.from_iso8601(data["inserted_at"] <> "Z")

               %{
                 "title" => data["title"],
                 "inserted_at" => inserted_at,
                 "updated_at" => updated_at
               }
             end)
             |> Enum.sort_by(& &1["updated_at"], {:desc, DateTime})
             |> Enum.map(
               &(&1
                 |> Map.replace("inserted_at", "timestamp")
                 |> Map.replace("updated_at", "timestamp"))
             ) ==
               expected
    end

    test "filtering: data search (inserted_at: before now)" do
      search_params = %{
        filters: [
          %{
            field: :inserted_at,
            op: :<=,
            value: offset_now(0)
          }
        ]
      }

      {:ok, {_results, meta}} =
        filtered_search("articles", TimestampsFacetSchema, search_params)

      expected = 3

      assert meta.total_count == expected
    end

    test "filtering: data search (inserted_at: equal or before first article)",
         context do
      %{articles: articles} = context

      first_article_inserted_at =
        articles
        |> Enum.map(&Map.from_struct(&1))
        |> Enum.sort_by(
          & &1.inserted_at,
          {:asc, DateTime}
        )
        |> List.first()
        |> Map.get(:inserted_at)

      search_params = %{
        filters: [
          %{
            field: :inserted_at,
            op: :<=,
            value: first_article_inserted_at
          }
        ]
      }

      {:ok, {_results, meta}} =
        filtered_search("articles", TimestampsFacetSchema, search_params)

      expected = 1

      assert meta.total_count == expected
    end

    test "sorting on inserted_at (datetime, desc)" do
      results = get_results_on_sort_by(:sort_inserted_at, :desc)

      expected = [
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
          "updated_at" => "timestamp"
        },
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
          "updated_at" => "timestamp"
        },
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne",
          "updated_at" => "timestamp"
        }
      ]

      assert results == expected
    end

    test "sorting on inserted_at (datetime, asc)" do
      results = get_results_on_sort_by(:sort_inserted_at, :asc)

      expected = [
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Géographie des marges : métaphores spatiales dans les traités politiques à l'époque moderne",
          "updated_at" => "timestamp"
        },
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
          "updated_at" => "timestamp"
        },
        %{
          "inserted_at" => "timestamp",
          "title" =>
            "Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture",
          "updated_at" => "timestamp"
        }
      ]

      assert results == expected
    end
  end

  describe "uuids" do
    setup do
      articles = init_resources(article_count: 3, insert_delay: 1_000)

      Fase.create_search_view(UUIDFacetSchema, "articles",
        scope: %{source: "authors"}
      )

      %{articles: articles}
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        %{
          data: %{"author" => true},
          id: true,
          text: true,
          sort_author: true
        },
        %{
          data: %{"author" => true},
          id: true,
          text: true,
          sort_author: true
        },
        %{
          data: %{"author" => true},
          id: true,
          text: true,
          sort_author: true
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", UUIDFacetSchema, search_params)

      assert results
             |> Enum.map(
               &%{
                 data: %{
                   "author" =>
                     match?(
                       {:ok, _},
                       Ecto.UUID.dump(&1.data["author"])
                     )
                 },
                 id:
                   match?(
                     {:ok, _},
                     Ecto.UUID.cast(&1.id)
                   ),
                 text:
                   match?(
                     {:ok, _},
                     Ecto.UUID.dump(&1.text)
                   ),
                 sort_author:
                   match?(
                     {:ok, _},
                     Ecto.UUID.dump(&1.text)
                   )
               }
             ) ==
               expected
    end
  end

  defp search_all(view_id, schema) do
    ecto_schema = Fase.ecto_schema(schema, view_id)

    from(ecto_schema)
    |> Repo.all()
  end

  defp filtered_search(view_id, schema, search_params, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 10)
    query_opts = Keyword.get(opts, :query_opts, [])
    extra_opts = Keyword.get(opts, :extra_opts, [])

    ecto_schema = Fase.ecto_schema(schema, view_id)
    query = from(ecto_schema)
    search_params = Map.put(search_params, :page_size, page_size)

    Flop.validate_and_run(query, search_params,
      for: schema,
      query_opts: query_opts,
      extra_opts: extra_opts
    )
  end

  defp facet_search(view_id, schema, search_params, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 10)
    query_opts = Keyword.get(opts, :query_opts, [])
    scope = Keyword.get(opts, :scope, [])

    ecto_schema = Fase.ecto_schema(schema, view_id)
    query = from(ecto_schema)
    search_params = Map.put(search_params, :page_size, page_size)

    with {:ok, search_results} <-
           Flop.validate_and_run(query, search_params,
             for: schema,
             query_opts: query_opts
           ),
         {:ok, facets} <-
           Fase.search(ecto_schema, search_params,
             query_opts: query_opts,
             scope: scope
           ) do
      {:ok, search_results, facets}
    else
      error ->
        error
    end
  end

  defp facet_result_subset(facet_results) do
    facet_results
    |> Enum.group_by(& &1.field)
    |> Enum.reduce(%{}, fn {group, results}, acc ->
      result = hd(results)

      Map.put(acc, group, %{
        count: Enum.count(result.options),
        first_2_options: Enum.take(result.options, 2)
      })
    end)
  end

  defp get_results_on_sort_by(sort_field, direction) do
    search_params = %{
      order_by: [sort_field],
      order_directions: [direction]
    }

    {:ok, {results, _meta}} =
      filtered_search("articles", TimestampsFacetSchema, search_params)

    results
    |> Enum.map(fn %{data: data} ->
      {:ok, updated_at, _} =
        DateTime.from_iso8601(data["updated_at"] <> "Z")

      {:ok, inserted_at, _} =
        DateTime.from_iso8601(data["inserted_at"] <> "Z")

      %{
        "title" => data["title"],
        "inserted_at" => inserted_at,
        "updated_at" => updated_at
      }
    end)
    |> Enum.map(
      &(&1
        |> Map.replace("inserted_at", "timestamp")
        |> Map.replace("updated_at", "timestamp"))
    )
  end
end
