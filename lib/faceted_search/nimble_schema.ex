defmodule FacetedSearch.NimbleSchema do
  @moduledoc false

  alias FacetedSearch.Errors.InvalidOptionsError
  alias FacetedSearch.Errors.MissingCallbackError

  @raw_faceted_search_option_schema [
    module: [
      type: :atom,
      doc: "The schema module that calls `use FacetedSearch`. This is inserted automatically."
    ],
    sources: [
      type: :keyword_list,
      required: true,
      keys: [
        *: [
          type: :keyword_list,
          keys: [
            prefix: [
              type: :string
            ],
            joins: [
              type: :keyword_list,
              keys: [
                *: [
                  type: :keyword_list,
                  keys: [
                    table: [
                      type: :atom
                    ],
                    on: [
                      type: :string,
                      required: true
                    ],
                    prefix: [
                      type: :string
                    ]
                  ]
                ]
              ]
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
                      required: true
                    ],
                    filter: [
                      type: {:tuple, [:atom, :atom, :keyword_list]}
                    ],
                    operators: [
                      type: {:list, :atom}
                    ]
                  ]
                ]
              ]
            ],
            data_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :any]}]}}
            ],
            text_fields: [
              type: {:list, :atom}
            ],
            facet_fields: [
              type: {:list, :atom}
            ],
            sort_fields: [
              type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}}
            ],
            scopes: [
              type: {:list, :atom}
            ]
          ]
        ]
      ]
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
      Keyword.get_values(opts, :sources)
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
