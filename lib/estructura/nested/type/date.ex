defmodule Estructura.Nested.Type.Date do
  @moduledoc """
  `Estructura` type implementation for handling `Date` values.

  This type provides functionality for:
  - Generating Date values for testing
  - Coercing various inputs into Date format
  - Validating Date values

  ## Examples

      iex> alias Estructura.Nested.Type.Date
      iex> Date.validate(~D[2024-01-01])
      {:ok, ~D[2024-01-01]}

      iex> alias Estructura.Nested.Type.Date
      iex> Date.validate("not a date")
      {:error, "Expected date, got: \\"not a date\\""}

  The type implements the `Estructura.Nested.Type` behaviour, providing:
  - `generate/1` - Creates random Date values for property testing
  - `coerce/1` - Attempts to convert input into a Date
  - `validate/1` - Ensures a value is a valid Date
  """
  @behaviour Estructura.Nested.Type

  @doc """
  Generates random Date values for property-based testing.

  ## Options

  Accepts all options supported by `Estructura.StreamData.date/1`.

  ## Examples

      iex> Date.generate() |> Enum.take(1) |> List.first()
      #Date<...>

      iex> Date.generate(from: ~D[2024-01-01], to: ~D[2024-12-31]) |> Enum.take(1) |> List.first()
      #Date<2024-...>
  """
  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.date(opts)

  @doc """
  Attempts to coerce a value into a Date.

  Delegates to `Estructura.Coercers.Date.coerce/1` which handles various input formats
  including strings in ISO 8601 format and maps with date components.

  ## Examples

      iex> Date.coerce("2024-01-01")
      {:ok, ~D[2024-01-01]}

      iex> Date.coerce(%{year: 2024, month: 1, day: 1})
      {:ok, ~D[2024-01-01]}

      iex> Date.coerce("invalid")
      {:error, "Invalid Date format"}
  """
  @impl true
  defdelegate coerce(term), to: Estructura.Coercers.Date

  @doc """
  Validates that a term is a valid Date.

  Returns `{:ok, date}` for valid Date values,
  or `{:error, reason}` for invalid ones.

  ## Examples

      iex> Date.validate(~D[2024-01-01])
      {:ok, ~D[2024-01-01]}

      iex> Date.validate("2024")
      {:error, "Expected date, got: \\"2024\\""}
  """
  @impl true
  def validate(%Date{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected date, got: " <> inspect(other)}
end
