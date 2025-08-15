defmodule FacetedSearch.Test.Adapters.Ecto.FacetsTest do
  use FacetedSearch.Test.Integration.Case,
    async:
      Application.compile_env(:faceted_search, :async_integration_tests, true)

  import Ecto.Query
  import FacetedSearch.Test.Factory

  alias FacetedSearch.Test.MyApp.SimpleFacetSchema

  describe "facets (simple)" do
    setup do
      insert_list(10, :article)
      FacetedSearch.create_search_view(SimpleFacetSchema, "articles")
      :ok
    end

    test "facet results" do
      search_params = %{}

      {:ok, _search_results, facets} =
        facets_search("articles", SimpleFacetSchema, search_params)

      expected = [
        %FacetedSearch.Facet{
          field: :draft,
          options: [
            %FacetedSearch.Option{
              value: false,
              label: "false",
              count: 7,
              selected: false
            },
            %FacetedSearch.Option{
              value: true,
              label: "true",
              count: 3,
              selected: false
            }
          ],
          parent: nil
        }
      ]

      assert facets == expected
    end
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
