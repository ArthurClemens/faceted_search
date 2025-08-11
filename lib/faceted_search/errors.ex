defmodule FacetedSearch.Errors.InvalidOptionsError do
  @moduledoc false

  defexception [:key, :message, :value, :keys_path, :module]

  @indent "    "

  @doc false
  def from_nimble(%NimbleOptions.ValidationError{} = error, opts) do
    %__MODULE__{
      module: Keyword.fetch!(opts, :module),
      key: error.key,
      value: error.value,
      keys_path: error.keys_path,
      message: Exception.message(error)
    }
  end

  def messages(errors) do
    errors
    |> Enum.map_join("\n", fn error ->
      info =
        case error.error_type do
          :empty_lists ->
            """
            Invalid value for key "#{error.key}".
            Expected a non-empty keyword list.
            """

          :invalid_reference ->
            """
            Option "#{error.key}" is not supported.
            Expected a name that is listed in `fields`.
            """

          :invalid_value ->
            """
            Invalid value for "#{error.key}".
            Expected type: #{error.expected_type}.
            """

          :unsupported_option ->
            cond do
              error.option == :data_fields ->
                """
                Key "#{error.key}" is not supported or it is misconfigured.
                Valid entries are:
                - Names that are listed in `fields`.
                - A keyword list with a name that is listed in `fields` and nested key "cast".
                - A self-named keyword list with nested keys "binding" and "field", or "cast".
                """

              error[:supported_keys] ->
                """
                Key "#{error.key}" is not supported.
                Supported keys are: #{Enum.map_join(error.supported_keys, ", ", &~s("#{&1}"))}.
                """

              true ->
                ""
            end
        end

      path = Enum.join(error.path, ".")

      [
        %{
          text: "",
          indent: 1
        },
        %{
          text: "Module: #{error.module}",
          indent: 1
        },
        %{
          text: "Data path: #{path}",
          indent: 1
        }
      ]
      |> Enum.concat(
        info
        |> String.split("\n")
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(
          &%{
            text: &1,
            indent: 2
          }
        )
      )
      |> Enum.map_join("\n", &"#{String.duplicate(@indent, &1.indent)}#{&1.text}")
    end)
  end
end

defmodule FacetedSearch.Errors.MissingCallbackError do
  @moduledoc """
  Raised when no beahviour callback was specified.
  """

  defexception [:callback, :module]

  def message(error) do
    """

        No callback defined.

        Option "scopes" was used, and that requires the behaviour callback #{error.callback} to be defined in module #{error.module}.

        Example:

            For schema with option:

                scopes: [:current_user],
                ...

            Add a function `scope_by/2` that accepts the same key and a scope parameter to read from:

                def scope_by(:current_user, current_user) do
                  %{
                    field: "user_id",
                    comparison: "=",
                    value: current_user.id
                  }
                end
    """
  end
end

defmodule FacetedSearch.Errors.NoRepoError do
  @moduledoc """
  Raised when no Ecto repo was specified. A repo can be configured in Flop - see [Flop documentation](https://hexdocs.pm/flop).
  """

  defexception []

  def message(_) do
    """

    No repo specified.

    A repo can be configured in Flop - see Flop documentation at https://hexdocs.pm/flop
    or passed in the options parameter.
    """
  end
end

defmodule FacetedSearch.Errors.SearchViewError do
  @moduledoc """
  Raised when an error occurs when creating a materialized view.
  """

  defexception [:message]

  @impl true
  def exception(value) do
    message = """

    Search view error.

    Error creating search view:

        #{inspect(value)}

    """

    %FacetedSearch.Errors.SearchViewError{message: message}
  end
end
