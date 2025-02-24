defmodule Estructura.Nested.Type.String do
  @moduledoc """
  `Estructura` type for `String`
  """
  @behaviour Estructura.Nested.Type

  @impl true
  def generate(opts \\ []) do
    {kind_or_codepoints, opts} = Keyword.pop(opts, :kind_of_codepoints, :printable)
    StreamData.string(kind_or_codepoints, opts)
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
