defmodule FacetedSearch.Test.Adapters.Ecto.FacetedSearchTest do
  use FacetedSearch.Test.Integration.Case,
    async:
      Application.compile_env(:faceted_search, :async_integration_tests, true)

  import Ecto.Query
  import FacetedSearch.Test.Factory

  alias FacetedSearch.Test.MyApp.ExpandedFacetSchema
  alias FacetedSearch.Test.MyApp.SimpleFacetSchema
  alias FacetedSearch.Test.Repo

  describe "search view tests" do
    setup do
      init_resources(article_count: 2)

      :ok
    end

    test "the create_search_view/3 function" do
      expected = {:ok, "articles"}

      assert FacetedSearch.create_search_view(SimpleFacetSchema, "articles") ==
               expected
    end

    test "the search_view_exists?/3 function" do
      expected = false

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected

      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")

      expected = true

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected
    end

    test "the create_search_view_if_not_exists/3 function" do
      expected = false

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected

      FacetedSearch.create_search_view_if_not_exists(
        SimpleFacetSchema,
        "articles"
      )

      expected = true

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected
    end

    test "the refresh_search_view/3 function" do
      # Initial view has 2 items
      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")

      results = search_all("articles", SimpleFacetSchema)
      expected = 2
      assert Enum.count(results) == expected

      # Add 3 more items and refresh the view
      build_list(3, :insert_article)
      FacetedSearch.refresh_search_view(SimpleFacetSchema, "articles")
      results = search_all("articles", SimpleFacetSchema)
      expected = 5
      assert Enum.count(results) == expected
    end

    test "the drop_search_view/3 function" do
      # Initial view has 2 items
      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")

      expected = true

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected

      FacetedSearch.drop_search_view(SimpleFacetSchema, "articles")

      expected = false

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected
    end
  end

  describe "filtering" do
    setup do
      init_resources(article_count: 10)

      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")
      :ok
    end

    test "text search returns a text field" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "metaphors"}]
      }

      expected = [
        "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises Examines the use of geographic and boundary metaphors in 16th-18th century political writings to reveal shifting concepts of sovereignty and statehood."
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert results |> Enum.map(& &1.text) == expected
    end

    test "text search, single term" do
      search_params = %{
        filters: [%{field: :text, op: :ilike, value: "political"}]
      }

      expected = 2

      {:ok, {_results, meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "text search, multiple terms" do
      search_params = %{
        filters: [
          %{field: :text, op: :ilike, value: "political"},
          %{field: :text, op: :ilike, value: "treatises"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "data search returns data maps" do
      search_params = %{
        filters: [
          %{field: :title, op: :ilike, value: "political"}
        ]
      }

      expected = [
        %{
          "publish_date" => "datetime",
          "title" =>
            "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises",
          "author" => "Helena van Dijk"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert results
             |> Enum.map(fn %{data: data} ->
               data
               |> Map.replace("draft", "indeterminate")
               |> Map.replace("publish_date", "datetime")
             end) == expected
    end

    test "data search, data field :title" do
      search_params = %{
        filters: [
          %{field: :title, op: :ilike, value: "political"}
        ]
      }

      expected = 1

      {:ok, {_results, meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert meta.total_count == expected
    end

    test "data search, data field :author" do
      search_params = %{
        filters: [
          %{field: :author, op: :==, value: "Mateo Alvarez"}
        ]
      }

      expected = 2

      {:ok, {_results, meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert meta.total_count == expected
    end
  end

  describe "sorting" do
    setup do
      init_resources(article_count: 10)
      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")
      :ok
    end

    test "sorting on publish_date (datetime)" do
      search_params = %{
        order_by: [:sort_publish_date],
        order_directions: [:desc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

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
        filtered_search("articles", SimpleFacetSchema, search_params)

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
        filtered_search("articles", SimpleFacetSchema, search_params)

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

    test "facet results" do
      search_params = %{}

      {:ok, _search_results, facets} =
        facets_search("articles", ExpandedFacetSchema, search_params)

      expected = [
        %FacetedSearch.Facet{
          field: :author,
          options: [
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
            },
            %FacetedSearch.Option{
              count: 2,
              label: "Jean-Marie Leclerc",
              selected: false,
              value: "Jean-Marie Leclerc"
            },
            %FacetedSearch.Option{
              count: 2,
              label: "Mateo Alvarez",
              selected: false,
              value: "Mateo Alvarez"
            },
            %FacetedSearch.Option{
              count: 2,
              label: "Sven Olsson",
              selected: false,
              value: "Sven Olsson"
            }
          ],
          parent: nil
        }
      ]

      assert facets == expected
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
end
