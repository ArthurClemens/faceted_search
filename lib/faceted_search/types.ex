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
                {:scope, term()}
                | {:repo, module()}
                | {:tenant, String.t()}
      end

      if :config_options in unquote(includes) do
        @type config_option :: {:repo, module()}
      end

      if :flop_adapter_options in unquote(includes) do
        @type flop_adapter_option :: {:repo, module()} | {:query_opts, Keyword.t()}
      end
    end
  end
end
