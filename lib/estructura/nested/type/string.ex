defmodule Estructura.Nested.Type.String do
  @moduledoc """
  `Estructura` type for `String`
  """
  @behaviour Estructura.Nested.Type

  if Code.ensure_loaded?(StreamData) do
    @impl true
    def generate(opts \\ [], _payload \\ []) do
      {kind_or_codepoints, opts} = Keyword.pop(opts, :kind_of_codepoints, :printable)
      StreamData.string(kind_or_codepoints, opts)
    end
  else
    @impl true
    def generate(_opts \\ [], _payload \\ []),
      do:
        raise(
          "Estructura requires the optional :stream_data dependency for data generation; " <>
            "add {:stream_data, \"~> 1.0\"} to your dependencies"
        )
  end

  @impl true
  def coerce(term) do
    case String.Chars.impl_for(term) do
      nil -> {:ok, inspect(term)}
      _ -> {:ok, to_string(term)}
    end
  end

  @impl true
  def validate(term) when is_binary(term), do: {:ok, term}
  def validate(other), do: {:error, "Expected string, got: " <> inspect(other)}
end
