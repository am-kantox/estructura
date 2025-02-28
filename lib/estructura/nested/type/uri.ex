defmodule Estructura.Nested.Type.URI do
  @moduledoc """
  `Estructura` type for `Date`
  """
  @behaviour Estructura.Nested.Type

  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.uri(opts)

  @impl true
  defdelegate coerce(term), to: URI, as: :new

  @impl true
  def validate(%URI{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected URI, got: " <> inspect(other)}
end

if Code.ensure_loaded?(Jason.Encoder) do
  defimpl Jason.Encoder, for: URI do
    @moduledoc false
    def encode(%URI{} = uri, _opts), do: [?", URI.to_string(uri), ?"]
  end
end
