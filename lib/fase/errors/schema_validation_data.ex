defmodule Fase.SchemaValidationData do
  @moduledoc false

  defstruct [
    :error_type,
    :key,
    :keys_path,
    :message,
    :module,
    :path,
    :supported_keys,
    :value
  ]

  @indent "    "

  def new(data) do
    struct(__MODULE__, data)
  end

  def message(errors) do
    errors
    |> Enum.map_join("\n", fn error ->
      info =
        case error.error_type do
          :empty_lists ->
            """
            Invalid value for key "#{error.key}".
            Expected a non-empty keyword list.
            """

          :invalid_key ->
            """
            Key "#{error.key}" is not supported.
            Expected a key that is listed in `fields`.
            """

          :duplicate ->
            """
            Duplicate key "#{error.key}".
            The should differ from existing keys: #{Enum.map_join(error.supported_keys, ", ", &~s("#{&1}"))}.
            """

          :unlisted_join_binding ->
            """
            The value "#{error.key}" for key "binding" is not supported because it is not listed in "joins".
            Supported keys are: #{Enum.map_join(error.supported_keys, ", ", &~s("#{&1}"))}.
            """

          :unlisted ->
            """
            Key "#{error.key}" is not supported.
            Supported keys are: #{Enum.map_join(error.supported_keys, ", ", &~s("#{&1}"))}.
            """
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
      |> Enum.map_join(
        "\n",
        &"#{String.duplicate(@indent, &1.indent)}#{&1.text}"
      )
    end)
  end
end
