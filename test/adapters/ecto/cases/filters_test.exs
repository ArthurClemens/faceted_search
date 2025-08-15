defmodule FacetedSearch.Test.Adapters.Ecto.FiltersTest do
  use FacetedSearch.Test.Integration.Case,
    async:
      Application.compile_env(:faceted_search, :async_integration_tests, true)

  import Ecto.Query
  import FacetedSearch.Test.Factory

  alias FacetedSearch.Test.MyApp.SimpleFacetSchema
  alias FacetedSearch.Test.Repo

  describe "search view tests" do
    test "the create_search_view/3 function" do
      insert_list(2, :article)

      expected = {:ok, "articles"}

      assert FacetedSearch.create_search_view(SimpleFacetSchema, "articles") ==
               expected
    end

    test "the search_view_exists?/3 function" do
      insert_list(2, :article)

      expected = false

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected

      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")

      expected = true

      assert FacetedSearch.search_view_exists?(SimpleFacetSchema, "articles") ==
               expected
    end

    test "the create_search_view_if_not_exists/3 function" do
      insert_list(2, :article)

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
      insert_list(2, :article)
      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")

      results = search_all("articles", SimpleFacetSchema)
      expected = 2
      assert Enum.count(results) == expected

      # Add 3 more items and refresh the view
      insert_list(3, :article)
      FacetedSearch.refresh_search_view(SimpleFacetSchema, "articles")
      results = search_all("articles", SimpleFacetSchema)
      expected = 5
      assert Enum.count(results) == expected
    end

    test "the drop_search_view/3 function" do
      # Initial view has 2 items
      insert_list(2, :article)
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
      insert_list(10, :article)
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
          "draft" => true,
          "publish_date" => "datetime",
          "title" =>
            "Mapping the Margins: Spatial Metaphors in Early Modern Political Treatises"
        }
      ]

      {:ok, {results, _meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert results
             |> Enum.map(fn %{data: data} ->
               Map.replace(data, "publish_date", "datetime")
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

    test "data search, data field :draft" do
      search_params = %{
        filters: [
          %{field: :draft, op: :==, value: true}
        ]
      }

      expected = 3

      {:ok, {_results, meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      assert meta.total_count == expected
    end
  end

  describe "sorting" do
    setup do
      insert_list(5, :article)
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

    test "sorting on draft (boolean)" do
      search_params = %{
        order_by: [:sort_draft],
        order_directions: [:asc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      entries = Enum.map(results, & &1.sort_draft)
      expected = Enum.sort(entries, :asc)
      assert entries == expected
    end

    test "sorting with multiple order directions" do
      search_params = %{
        order_by: [:sort_draft, :sort_publish_date],
        order_directions: [:desc, :desc]
      }

      {:ok, {results, _meta}} =
        filtered_search("articles", SimpleFacetSchema, search_params)

      entries = Enum.map(results, &{&1.sort_draft, &1.sort_publish_date})

      expected =
        Enum.sort_by(results, &{!&1.sort_draft, !&1.sort_publish_date})
        |> Enum.map(&{&1.sort_draft, &1.sort_publish_date})

      assert entries == expected
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
end
