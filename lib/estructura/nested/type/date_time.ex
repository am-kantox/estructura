defmodule Estructura.Nested.Type.DateTime do
  @moduledoc """
  `Estructura` type implementation for handling `DateTime` values.

  This type provides functionality for:
  - Generating DateTime values for testing
  - Coercing various inputs into DateTime format
  - Validating DateTime values

  ## Examples

      iex> alias Estructura.Nested.Type.DateTime
      iex> DateTime.validate(~U[2024-01-01 10:00:00Z])
      {:ok, ~U[2024-01-01 10:00:00Z]}

      iex> alias Estructura.Nested.Type.DateTime
      iex> DateTime.validate("not a datetime")
      {:error, "Expected date, got: \\"not a datetime\\""}

  The type implements the `Estructura.Nested.Type` behaviour, providing:
  - `generate/1` - Creates random DateTime values for property testing
  - `coerce/1` - Attempts to convert input into a DateTime
  - `validate/1` - Ensures a value is a valid DateTime
  """
  @behaviour Estructura.Nested.Type

  @doc """
  Generates random DateTime values for property-based testing.

  ## Options

  Accepts all options supported by `Estructura.StreamData.datetime/1`.

  ## Examples

      iex> DateTime.generate() |> Enum.take(1) |> List.first()
      #DateTime<...>
  """
  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.datetime(opts)

  @doc """
  Attempts to coerce a value into a DateTime.

  Delegates to `Estructura.Coercers.DateTime.coerce/1` which handles various input formats.

  ## Examples

      iex> DateTime.coerce("2024-01-01T10:00:00Z")
      {:ok, ~U[2024-01-01 10:00:00Z]}

      iex> DateTime.coerce("invalid")
      {:error, "Invalid DateTime format"}
  """
  @impl true
  defdelegate coerce(term), to: Estructura.Coercers.DateTime

  @doc """
  Validates that a term is a valid DateTime.

  Returns `{:ok, datetime}` for valid DateTime values,
  or `{:error, reason}` for invalid ones.

  ## Examples

      iex> DateTime.validate(~U[2024-01-01 10:00:00Z])
      {:ok, ~U[2024-01-01 10:00:00Z]}

      iex> DateTime.validate("2024")
      {:error, "Expected date, got: \\"2024\\""}
  """
  @impl true
  def validate(%DateTime{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected date, got: " <> inspect(other)}
end
