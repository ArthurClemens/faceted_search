defmodule FacetedSearch.NimbleSchema do
  @moduledoc false

  alias FacetedSearch.Errors.InvalidOptionsError
  alias FacetedSearch.Errors.MissingCallbackError

  @raw_faceted_search_option_schema [
    module: [
      type: :atom,
      doc: "The schema module that calls `use FacetedSearch`. Automatically inserted."
    ],
    collections: [
      type: :keyword_list,
      required: true,
      keys: [
        *: [
          type: :keyword_list,
          keys: [
            prefix: [
              type: :string,
              doc: """
              Use when the source table is located in a different database schema.
              """
            ],
            joins: [
              type:
                {:list,
                 {:keyword_list,
                  table: [
                    type: :atom,
                    required: true,
                    doc: "Table name."
                  ],
                  as: [
                    type: :atom,
                    doc: "Table alias."
                  ],
                  on: [
                    type: :string,
                    required: true,
                    doc: "Joins the table using an ON clause."
                  ],
                  prefix: [
                    type: :string,
                    doc: "Database schema other than 'public'."
                  ]}}
            ],
            fields: [
              type: :keyword_list,
              keys: [
                *: [
                  type: :keyword_list,
                  keys: [
                    binding: [type: :atom],
                    field: [type: :atom],
                    ecto_type: [
                      type: :any,
                      required: true,
                      doc: """
                      Identical to the Flop option.

                      From the Flop documentation:
                      > The Ecto type of the field. The filter operator and value validation is based on this option.
                      """
                    ],
                    filter: [
                      type: {:tuple, [:atom, :atom, :keyword_list]},
                      doc: """
                      Identical to the Flop option, except that a default filter is applied by FacetSearch, making this option optional. If set, this option overrides the default filter.

                      From the Flop documentation:
                      > A module/function/options tuple referencing a custom filter function. The function must take the Ecto query, the Flop.Filter struct, and the options from the tuple as arguments.
                      """
                    ],
                    operators: [
                      type: {:list, :atom},
                      doc: """
                      Identical to the Flop option.

                      From the Flop documentation:
                      > Defines which filter operators are allowed for this field. If omitted, all operators will be accepted.
                      """
                    ]
                  ]
                ]
              ],
              doc: """
              A list of database columns used to provide structured data.
              """
            ],
            data_fields: [
              type: {:list, :atom},
              doc: """
              A list of database columns used for filtering. These should be a subset of the fields listed in `fields`.
              """
            ],
            text_fields: [
              type: {:list, :atom},
              doc: """
              A list of database columns used for text search. These should be a subset of the fields listed in `fields`.
              """
            ],
            facet_fields: [
              type: {:list, :atom},
              doc: """
              A list of database columns used to create facets. These should be a subset of the fields listed in `fields`.
              """
            ],
            scopes: [
              type: {:list, :atom},
              doc: """
              Activates scoping the table contents. See: [Scoping data](#module-scoping-data).
              """
            ]
          ]
        ]
      ],
      doc: """
      Settings per collection. The collection key is the name of a table in your repo.
      """
    ]
  ]

  @option_schema NimbleOptions.new!(@raw_faceted_search_option_schema)

  def option_schema, do: @option_schema

  def validate!(opts, module) do
    validate!(opts, option_schema(), module)
  end

  def validate!(opts, %NimbleOptions{} = schema, module) do
    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        validate_scope_callback(opts, opts[:module])

        opts

      {:error, err} ->
        raise InvalidOptionsError.from_nimble(err,
                module: module
              )
    end
  end

  defp validate_scope_callback(opts, module) do
    has_scopes_option =
      Keyword.get_values(opts, :collections)
      |> List.flatten()
      |> Enum.map(fn {_, sublist} ->
        Keyword.has_key?(sublist, :scopes) and Keyword.get(sublist, :scopes) != []
      end)
      |> List.flatten()
      |> Enum.any?()

    require_scope_by_callback(module, has_scopes_option)
  end

  defp require_scope_by_callback(module, has_scopes_option) when has_scopes_option do
    if not Module.defines?(module, {:scope_by, 2}) do
      raise MissingCallbackError.message(%{
              callback: "scope_by/2",
              module: module
            })
    end
  end

  defp require_scope_by_callback(_module, _has_scopes_option), do: nil
end
