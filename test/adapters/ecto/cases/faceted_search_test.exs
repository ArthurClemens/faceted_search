defmodule FacetedSearch.Test.Adapters.Ecto.FacetedSearchTest do
  use FacetedSearch.Test.Integration.Case,
    async:
      Application.compile_env(:faceted_search, :async_integration_tests, true)

  import Ecto.Query
  import FacetedSearch.Test.Factory

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
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
          %{field: :text, op: :ilike_and, value: "political treatises"}
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
        ["History", "Language analysis: Critical reading", "Politics"],
        ["History", "Manuscripts", "Semiotics"],
        ["Books", "History", "Materiality"],
        ["History", "Music", "Religion"]
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", ExpandedFacetSchema, search_params)

      assert get_in(results, [Access.all(), Access.key(:data), "tag_titles"]) ==
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
        facets_search("articles", ExpandedFacetSchema, search_params)

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
        facets_search("articles", ExpandedFacetSchema, search_params)

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
        facets_search("articles", ExpandedFacetSchema, search_params)

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
        facets_search("articles", ExpandedFacetSchema, search_params)

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
        }
      }

      assert meta.total_count == 7
      assert facet_result_subset(facets) == expected

      expected_publish_date_options = [
        %FacetedSearch.Option{
          count: 1,
          label: "last year",
          value: 1,
          selected: false
        },
        %FacetedSearch.Option{
          count: 1,
          label: "last quarter",
          value: 2,
          selected: false
        },
        %FacetedSearch.Option{
          count: 3,
          label: "last month",
          value: 3,
          selected: false
        },
        %FacetedSearch.Option{
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
        facets_search("articles", ExpandedFacetSchema, search_params)

      expected = %{
        author: %{
          count: 3,
          first_2_options: [
            %FacetedSearch.Option{
              count: 1,
              label: "Jean-Marie Leclerc",
              selected: false,
              value: "Jean-Marie Leclerc"
            },
            %FacetedSearch.Option{
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
          count: 8,
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
              count: 1,
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

      assert meta.total_count == 3
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
          label: "today",
          selected: false,
          value: 5
        }
      ]

      assert Enum.find(facets, &(&1.field == :publish_date))
             |> get_in([Access.key(:options)]) == expected_publish_date_options
    end
  end

  defp search_all(view_id, schema) do
    ecto_schema = FacetedSearch.ecto_schema(schema, view_id)

    from(ecto_schema)
    |> Repo.all()
  end

  defp filtered_search(view_id, schema, search_params) do
    ecto_schema = FacetedSearch.ecto_schema(schema, view_id)
    query = from(ecto_schema)
    search_params = Map.put(search_params, :page_size, 10)

    Flop.validate_and_run(query, search_params, for: schema)
  end

  defp facets_search(view_id, schema, search_params) do
    ecto_schema = FacetedSearch.ecto_schema(schema, view_id)
    query = from(ecto_schema)
    search_params = Map.put(search_params, :page_size, 10)

    with {:ok, search_results} <-
           Flop.validate_and_run(query, search_params, for: schema),
         {:ok, facets} <-
           FacetedSearch.search(ecto_schema, search_params) do
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
