defmodule FacetedSearch.Test.Adapters.Ecto.FacetedSearchTest do
  use FacetedSearch.Test.Integration.Case,
    async:
      Application.compile_env(:faceted_search, :async_integration_tests, true)

  import Ecto.Query
  import FacetedSearch.Test.Factory

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
  alias FacetedSearch.Test.MyApp.MultipleSourcesFacetSchema
  alias FacetedSearch.Test.MyApp.PrefixFacetSchema
  alias FacetedSearch.Test.MyApp.ScopedFacetSchema
  alias FacetedSearch.Test.Repo

  describe "search view" do
    setup do
      init_resources(article_count: 2)

      :ok
    end

    test "the create_search_view/3 function" do
      expected = {:ok, "articles"}

      assert FacetedSearch.create_search_view(ExpandedFacetSchema, "articles") ==
               expected
    end

    test "the search_view_exists?/3 function" do
      expected = false

      assert FacetedSearch.search_view_exists?(ExpandedFacetSchema, "articles") ==
               expected

      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")

      expected = true

      assert FacetedSearch.search_view_exists?(ExpandedFacetSchema, "articles") ==
               expected
    end

    test "the create_search_view_if_not_exists/3 function" do
      expected = false

      assert FacetedSearch.search_view_exists?(ExpandedFacetSchema, "articles") ==
               expected

      FacetedSearch.create_search_view_if_not_exists(
        ExpandedFacetSchema,
        "articles"
      )

      expected = true

      assert FacetedSearch.search_view_exists?(ExpandedFacetSchema, "articles") ==
               expected
    end

    test "the refresh_search_view/3 function" do
      # Initial view has 2 items
      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")

      results = search_all("articles", ExpandedFacetSchema)
      expected = 2
      assert Enum.count(results) == expected

      # Add 3 more items and refresh the view
      build_list(3, :insert_article)
      FacetedSearch.refresh_search_view(ExpandedFacetSchema, "articles")
      results = search_all("articles", ExpandedFacetSchema)
      expected = 5
      assert Enum.count(results) == expected
    end

    test "the drop_search_view/3 function" do
      # Initial view has 2 items
      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")

      expected = true

      assert FacetedSearch.search_view_exists?(ExpandedFacetSchema, "articles") ==
               expected

      FacetedSearch.drop_search_view(ExpandedFacetSchema, "articles")
      expected = false

      assert FacetedSearch.search_view_exists?(ExpandedFacetSchema, "articles") ==
               expected
    end
  end

  describe "filtering: text search" do
    setup do
      init_resources(article_count: 10)

      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")
      :ok
    end

    test "text field result" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "metaphors"}]
      }

      expected = [
        "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood. Helena van Dijk"
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

      assert results |> Enum.map(& &1.text) == expected
    end

    test "single term" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "political"}]
      }

      expected = 2

      {:ok, {_results, meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "multiple terms" do
      search_params = %{
        filters: [
          %{field: :text, op: :ilike, value: "political"},
          %{field: :text, op: :ilike, value: "treatises"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "multiple terms using ilike_and" do
      search_params = %{
        filters: [
          %{field: :text, op: :ilike, value: "political treatises"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

      assert meta.total_count == expected
    end
  end

  describe "filtering: data search" do
    setup do
      init_resources(article_count: 10)

      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")
      :ok
    end

    test "data field result" do
      search_params = %{
        filters: [
          %{field: :title, op: :ilike, value: "political"}
        ]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

      expected = [
        %{
          "publish_date" => "datetime",
          "title" =>
            "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises",
          "tags" => ["history", "language_analysis", "politics"],
          "tag_titles" => [
            "History",
            "Language analysis: Critical reading",
            "Politics"
          ],
          "author" => "Helena van Dijk",
          "word_count" => 3473
        }
      ]

      assert results
             |> Enum.map(fn %{data: data} ->
               data
               |> Map.replace("draft", "indeterminate")
               |> Map.replace("publish_date", "datetime")
             end) == expected
    end

    test "search subfield: title (ilike)" do
      search_params = %{
        filters: [
          %{field: :title, op: :ilike, value: "political"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

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
        filtered_search("articles", ExpandedFacetSchema, search_params)

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
        filtered_search("articles", ExpandedFacetSchema, search_params)

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
        filtered_search("articles", ExpandedFacetSchema, search_params)

      assert get_in(results, [Access.all(), Access.key(:data), "tag_titles"]) ==
               expected
    end
  end

  describe "sorting" do
    setup do
      init_resources(article_count: 10)
      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")
      :ok
    end

    test "sorting on publish_date (datetime)" do
      search_params = %{
        order_by: [:sort_publish_date],
        order_directions: [:desc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

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
        filtered_search("articles", ExpandedFacetSchema, search_params)

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
        filtered_search("articles", ExpandedFacetSchema, search_params)

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
      FacetedSearch.create_search_view(ExpandedFacetSchema, "articles")

      :ok
    end

    test "facet results (no search params)" do
      search_params = %{}

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %FacetedSearch.Option{
              count: 2,
              label: "Helena van Dijk",
              selected: false,
              value: "Helena van Dijk"
            }
          ]
        },
        tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              count: 1,
              label: "Archives",
              value: "archives",
              selected: false
            },
            %FacetedSearch.Option{
              count: 1,
              label: "Books",
              value: "books",
              selected: false
            }
          ]
        },
        word_count: %{
          count: 3,
          first_2_options: [
            %FacetedSearch.Option{
              count: 5,
              label: "2000-4000",
              selected: false,
              value: 1
            },
            %FacetedSearch.Option{
              count: 2,
              label: "4000-6000",
              selected: false,
              value: 2
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "books",
              label: "books",
              count: 1,
              selected: false
            }
          ]
        },
        publish_date: %{
          count: 4,
          first_2_options: [
            %FacetedSearch.Option{
              count: 3,
              label: "last year",
              selected: false,
              value: 1
            },
            %FacetedSearch.Option{
              count: 2,
              label: "last quarter",
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
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: true
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        tags: %{
          count: 11,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "Archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              count: 2,
              label: "2000-4000",
              selected: false,
              value: 1
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              count: 3,
              label: "last year",
              selected: false,
              value: 1
            },
            %FacetedSearch.Option{
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
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 1,
              selected: true
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "Archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
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
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        publish_date: %{
          count: 4,
          first_2_options: [
            %FacetedSearch.Option{
              value: 1,
              label: "last year",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: 2,
              label: "last quarter",
              count: 1,
              selected: false
            }
          ]
        },
        tags: %{
          count: 14,
          first_2_options: [
            %FacetedSearch.Option{
              value: "books",
              label: "Books",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "culture",
              label: "Culture",
              count: 1,
              selected: false
            }
          ]
        },
        word_count: %{
          count: 3,
          first_2_options: [
            %FacetedSearch.Option{
              count: 5,
              label: "2000-4000",
              selected: true,
              value: 1
            },
            %FacetedSearch.Option{
              count: 2,
              label: "4000-6000",
              selected: true,
              value: 2
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "books",
              label: "books",
              count: 1,
              selected: false
            }
          ]
        }
      }

      assert meta.total_count == 7
      assert facet_result_subset(facets) == expected

      expected_publish_date_options = [
        %FacetedSearch.Option{
          count: 1,
          label: "last year",
          selected: false,
          value: 1
        },
        %FacetedSearch.Option{
          count: 1,
          label: "last quarter",
          selected: false,
          value: 2
        },
        %FacetedSearch.Option{
          count: 3,
          label: "last month",
          selected: false,
          value: 3
        },
        %FacetedSearch.Option{
          count: 2,
          label: "last week",
          selected: false,
          value: 4
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
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 4,
          first_2_options: [
            %FacetedSearch.Option{
              count: 1,
              label: "Helena van Dijk",
              value: "Helena van Dijk",
              selected: false
            },
            %FacetedSearch.Option{
              count: 1,
              label: "Jean-Marie Leclerc",
              selected: false,
              value: "Jean-Marie Leclerc"
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              count: 2,
              label: "Aisha Rahman",
              selected: false,
              value: "Aisha Rahman"
            },
            %FacetedSearch.Option{
              count: 1,
              label: "Helena van Dijk",
              selected: false,
              value: "Helena van Dijk"
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              count: 1,
              label: "archives",
              selected: false,
              value: "archives"
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              count: 3,
              label: "last year",
              selected: false,
              value: 1
            },
            %FacetedSearch.Option{
              count: 2,
              label: "last quarter",
              selected: false,
              value: 2
            }
          ]
        },
        tags: %{
          count: 12,
          first_2_options: [
            %FacetedSearch.Option{
              count: 1,
              label: "Culture",
              selected: false,
              value: "culture"
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              count: 3,
              label: "2000-4000",
              selected: false,
              value: 1
            },
            %FacetedSearch.Option{
              count: 2,
              label: "4000-6000",
              selected: false,
              value: 2
            }
          ]
        }
      }

      assert meta.total_count == 5
      assert facet_result_subset(facets) == expected

      expected_publish_date_options = [
        %FacetedSearch.Option{
          count: 3,
          label: "last year",
          selected: false,
          value: 1
        },
        %FacetedSearch.Option{
          count: 2,
          label: "last quarter",
          selected: false,
          value: 2
        },
        %FacetedSearch.Option{
          count: 3,
          label: "last month",
          selected: true,
          value: 3
        },
        %FacetedSearch.Option{
          count: 2,
          label: "last week",
          selected: true,
          value: 4
        }
      ]

      assert Enum.find(facets, &(&1.field == :publish_date))
             |> get_in([Access.key(:options)]) == expected_publish_date_options
    end

    test "search facets: hierarchies (level 1)" do
      search_params = %{
        filters: [
          %{
            value: ["Aisha Rahman", "Helena van Dijk"],
            op: :==,
            field: :facet_category_author
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 2,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: false
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: true
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 2,
              selected: true
            }
          ]
        },
        category_author_tags: %{
          count: 12,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman>books",
              label: "Aisha Rahman>books",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Aisha Rahman>emotion",
              label: "Aisha Rahman>emotion",
              count: 1,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "books",
              label: "books",
              count: 1,
              selected: false
            }
          ]
        },
        publish_date: %{
          count: 3,
          first_2_options: [
            %FacetedSearch.Option{
              value: 1,
              label: "last year",
              count: 2,
              selected: false
            },
            %FacetedSearch.Option{
              value: 2,
              label: "last quarter",
              count: 1,
              selected: false
            }
          ]
        },
        tags: %{
          count: 11,
          first_2_options: [
            %FacetedSearch.Option{
              value: "books",
              label: "Books",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "emotion",
              label: "Emotion",
              count: 1,
              selected: false
            }
          ]
        },
        word_count: %{
          count: 2,
          first_2_options: [
            %FacetedSearch.Option{
              value: 1,
              label: "2000-4000",
              count: 3,
              selected: false
            },
            %FacetedSearch.Option{
              value: 3,
              label: "6000-8000",
              count: 1,
              selected: false
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
            value: ["Helena van Dijk>history"],
            op: :==,
            field: :facet_category_author_tags
          }
        ]
      }

      {:ok, {_results, meta}, facets} =
        facet_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 1,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 1,
              selected: false
            }
          ]
        },
        category_author: %{
          count: 5,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Aisha Rahman",
              label: "Aisha Rahman",
              count: 2,
              selected: false
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk",
              label: "Helena van Dijk",
              count: 1,
              selected: true
            }
          ]
        },
        category_author_tags: %{
          count: 6,
          first_2_options: [
            %FacetedSearch.Option{
              value: "Helena van Dijk>history",
              label: "Helena van Dijk>history",
              count: 1,
              selected: true
            },
            %FacetedSearch.Option{
              value: "Helena van Dijk>interdisciplinary",
              label: "Helena van Dijk>interdisciplinary",
              count: 1,
              selected: false
            }
          ]
        },
        category_tags: %{
          count: 20,
          first_2_options: [
            %FacetedSearch.Option{
              value: "archives",
              label: "archives",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
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
            %FacetedSearch.Option{
              value: 2,
              label: "last quarter",
              count: 1,
              selected: false
            }
          ]
        },
        tags: %{
          count: 3,
          first_2_options: [
            %FacetedSearch.Option{
              value: "history",
              label: "History",
              count: 1,
              selected: false
            },
            %FacetedSearch.Option{
              value: "language_analysis",
              label: "Language analysis: Critical reading",
              count: 1,
              selected: false
            }
          ]
        },
        word_count: %{
          count: 1,
          first_2_options: [
            %FacetedSearch.Option{
              value: 1,
              label: "2000-4000",
              count: 1,
              selected: false
            }
          ]
        }
      }

      assert meta.total_count == 1
      assert facet_result_subset(facets) == expected
    end
  end

  describe "scopes (word_count)" do
    setup do
      init_resources(article_count: 10)

      FacetedSearch.create_search_view(ScopedFacetSchema, "articles",
        scopes: %{word_count: 4000}
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

  describe "scopes (publish_date)" do
    setup do
      init_resources(article_count: 10)

      now = ~U[2025-09-05 23:13:46.493983Z]
      last_month = now |> DateTime.add(-30, :day)

      FacetedSearch.create_search_view(ScopedFacetSchema, "articles",
        scopes: %{publish_date: last_month}
      )

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        "2025-08-27",
        "2025-08-27",
        "2025-08-27",
        "2025-09-05",
        "2025-09-05"
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ScopedFacetSchema, search_params)

      assert results
             |> Enum.map(&(&1.data["publish_date"] |> String.slice(0, 10)))
             |> Enum.sort() ==
               expected
    end
  end

  describe "scopes (combined word_count and publish_date)" do
    setup do
      init_resources(article_count: 10)

      now = ~U[2025-09-05 23:13:46.493983Z]
      last_month = now |> DateTime.add(-30, :day)

      FacetedSearch.create_search_view(ScopedFacetSchema, "articles",
        scopes: %{word_count: 4000, publish_date: last_month}
      )

      :ok
    end

    test "results without filters" do
      search_params = %{}

      expected = [
        %{
          "publish_date" => "2025-08-27",
          "title" =>
            "Spectral Agency: Ghost Narratives as Cultural Memory Archives",
          "word_count" => 4898
        },
        %{
          "publish_date" => "2025-08-27",
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
                 &1.data["publish_date"] |> String.slice(0, 10)
               )
             )
             |> Enum.sort_by(& &1["word_count"]) ==
               expected
    end
  end

  describe "multiple sources schema" do
    setup do
      init_resources(article_count: 10)

      FacetedSearch.create_search_view(MultipleSourcesFacetSchema, "articles")

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

    test "filter on shared data field (author)" do
      search_params = %{
        filters: [
          %{field: :author, op: :==, value: "Helena van Dijk"}
        ]
      }

      expected = [
        %{
          data: %{
            "author" => "Helena van Dijk",
            "birthdate" => "1977-01-25",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Helena van Dijk",
            "publish_date" => "2025-07-06T23:13:46",
            "title" =>
              "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises"
          },
          source: "articles"
        },
        %{
          data: %{
            "author" => "Helena van Dijk",
            "publish_date" => "2025-09-05T23:13:46",
            "title" =>
              "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories"
          },
          source: "articles"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.map(&%{source: &1.source, data: &1.data})
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
            "author" => "Helena van Dijk",
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

      expected = ["authors Sven Olsson 1947-10-22"]

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
            "author" => "Helena van Dijk",
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
          sort_author: "Helena van Dijk",
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
          sort_author: "Helena van Dijk",
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
          %{field: :facet_author, op: :==, value: ["Helena van Dijk"]}
        ]
      }

      expected = [
        %{
          data: %{
            "author" => "Helena van Dijk",
            "birthdate" => "1977-01-25",
            "source" => "authors"
          },
          source: "authors"
        },
        %{
          data: %{
            "author" => "Helena van Dijk",
            "publish_date" => "2025-07-06T23:13:46",
            "title" =>
              "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises"
          },
          source: "articles"
        },
        %{
          data: %{
            "author" => "Helena van Dijk",
            "publish_date" => "2025-09-05T23:13:46",
            "title" =>
              "Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories"
          },
          source: "articles"
        }
      ]

      {:ok, {results, _meta}, facets} =
        facet_search("articles", MultipleSourcesFacetSchema, search_params)

      assert results
             |> Enum.map(&%{source: &1.source, data: &1.data})
             |> Enum.sort() == expected

      expected_source_options = [
        %FacetedSearch.Option{
          value: "articles",
          label: "articles",
          count: 2,
          selected: false
        },
        %FacetedSearch.Option{
          value: "authors",
          label: "authors",
          count: 1,
          selected: false
        }
      ]

      assert Enum.find(facets, &(&1.field == :source))
             |> get_in([Access.key(:options)]) == expected_source_options
    end
  end

  describe "scopes with sources" do
    setup do
      init_resources(article_count: 10)

      FacetedSearch.create_search_view(MultipleSourcesFacetSchema, "articles",
        scopes: %{source: "authors"}
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

      FacetedSearch.create_search_view(PrefixFacetSchema, "articles",
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
            "From Papyrus to Pixel: Materiality and Meaning in the Evolution of the Book, Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises, Narrative Entropy: Chaos Theory and Structure in Modernist Fiction, Semiotic Networks: Symbol Transmission in Medieval Manuscript Culture, Temporalities of Memory: An Interdisciplinary Approach to Post-War Oral Histories",
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

  defp search_all(view_id, schema) do
    ecto_schema = FacetedSearch.ecto_schema(schema, view_id)

    from(ecto_schema)
    |> Repo.all()
  end

  defp filtered_search(view_id, schema, search_params, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 10)
    query_opts = Keyword.get(opts, :query_opts, [])

    ecto_schema = FacetedSearch.ecto_schema(schema, view_id)
    query = from(ecto_schema)
    search_params = Map.put(search_params, :page_size, page_size)

    Flop.validate_and_run(query, search_params,
      for: schema,
      query_opts: query_opts
    )
  end

  defp facet_search(view_id, schema, search_params, opts \\ []) do
    page_size = Keyword.get(opts, :page_size, 10)
    query_opts = Keyword.get(opts, :query_opts, [])

    ecto_schema = FacetedSearch.ecto_schema(schema, view_id)
    query = from(ecto_schema)
    search_params = Map.put(search_params, :page_size, page_size)

    with {:ok, search_results} <-
           Flop.validate_and_run(query, search_params,
             for: schema,
             query_opts: query_opts
           ),
         {:ok, facets} <-
           FacetedSearch.search(ecto_schema, search_params,
             query_opts: query_opts
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
end
