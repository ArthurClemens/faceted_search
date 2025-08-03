defmodule FacetedSearch.Types do
  @moduledoc false

  defmacro __using__(opts \\ []) do
    includes = Keyword.get(opts, :include, [])

    quote do
      if :schema_options in unquote(includes) do
        @type schema_options() :: [
                unquote(NimbleOptions.option_typespec(FacetedSearch.NimbleSchema.option_schema()))
              ]
      end

      if :create_search_view_options in unquote(includes) do
        @type create_search_view_option ::
                {:scopes, term()}
                | {:repo, module()}
                | {:tenant, String.t()}
                | {:timeout, integer()}
                | {:pool_timeout, integer()}
      end

      if :refresh_search_view_options in unquote(includes) do
        @type refresh_search_view_option ::
                {:concurrently, boolean()}
                | {:timeout, integer()}
      end

      if :config_options in unquote(includes) do
        @type config_option :: {:repo, module()}
      end

      if :facet_search_options in unquote(includes) do
        @type facet_search_option ::
                {:repo, module()}
                | {:query_opts, Keyword.t() | {:cache_facets, boolean()}}
      end

      if :range_types in unquote(includes) do
        @type range_bound :: number()
        @type range_bucket_lower :: list(:lower | range_bound())
        @type range_bucket_middle :: list(range_bound())
        @type range_bucket_upper :: list(range_bound() | :upper)
        @type range_bucket ::
                {range_bucket_lower() | range_bucket_middle() | range_bucket_upper(), integer()}
      end
    end
  end
end
