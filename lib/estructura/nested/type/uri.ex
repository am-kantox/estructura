defmodule Estructura.Nested.Type.URI do
  @moduledoc """
  `Estructura` type implementation for handling `URI` values.

  This type provides functionality for:
  - Generating URI values for testing
  - Coercing string and map inputs into URI structs
  - Validating URI values

  ## Examples

  Estructura.Nested.Type.URI.validate(URI.parse("https://example.com/path?query=value"))
  #⇒ {:ok, %URI{scheme: "https", host: "example.com", path: "/path", query: "query=value"}}

  Estructura.Nested.Type.URI.validate("not a uri")
  #⇒ {:error, "Expected URI, got: \\"not a uri\\""}

  The type implements the `Estructura.Nested.Type` behaviour, providing:
  - `generate/1` - Creates random URI values for property testing
  - `coerce/1` - Attempts to convert input into a URI
  - `validate/1` - Ensures a value is a valid URI
  """
  @behaviour Estructura.Nested.Type

  @doc """
  Generates random URI values for property-based testing.

  ## Options

  Accepts all options supported by `Estructura.StreamData.uri/1`, including:
  - `:schemes` - List of allowed schemes (default: ["http", "https"])
  - `:hosts` - List of allowed hosts (default: generates random hosts)
  - `:paths` - List of allowed paths (default: generates random paths)
  - `:with_query` - Whether to include query parameters (default: true)

  ## Examples

  Estructura.Nested.Type.URI.generate() |> Enum.take(1) |> List.first()
  #⇒ %URI{scheme: "https", host: "example.com", path: "/some/path"}

  Estructura.Nested.Type.URI.generate(schemes: ["ftp"]) |> Enum.take(1) |> List.first()
  #⇒ %URI{scheme: "ftp", host: "example.com", path: "/"}
  """
  @impl true
  def generate(opts \\ [], _payload \\ []), do: Estructura.StreamData.uri(opts)

  @doc """
  Attempts to coerce a value into a URI.

  Delegates to `URI.new/1` which handles various input formats including:
  - URI strings ("https://example.com")
  - Maps with URI components

  ## Examples

  Estructura.Nested.Type.URI.coerce("https://example.com/path?query=value")
  #⇒ {:ok, %URI{scheme: "https", host: "example.com", path: "/path", query: "query=value"}}

  Estructura.Nested.Type.URI.coerce("invalid uri")
  #⇒ {:error, "Invalid URI format"}
  """
  @impl true
  def coerce(term) do
    URI.new(term)
  rescue
    e -> {:error, e}
  end

  @doc """
  Validates that a term is a valid URI.

  Returns `{:ok, uri}` for valid URI values,
  or `{:error, reason}` for invalid ones.

  ## Examples

  Estructura.Nested.Type.URI.validate(URI.parse("https://example.com"))
  #⇒ {:ok, %URI{scheme: "https", host: "example.com"}}

  Estructura.Nested.Type.URI.validate("not a uri")
  #⇒ {:error, "Expected URI, got: \\"not a uri\\""}
  """
  @impl true
  def validate(%URI{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected URI, got: " <> inspect(other)}
end

defimpl Estructura.Flattenable, for: URI do
  @moduledoc false
  def flatten(%URI{} = uri, _opts), do: to_string(uri)
end

if match?({:module, Jason.Encoder}, Code.ensure_compiled(Jason.Encoder)) do
  defimpl Jason.Encoder, for: URI do
    @moduledoc false
    def encode(%URI{} = uri, _opts), do: [?", URI.to_string(uri), ?"]
  end
end
