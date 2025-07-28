defmodule Estructura.Nested.Type.Time do
  @moduledoc """
  `Estructura` type implementation for handling `Time` values.

  This type provides functionality for:
  - Generating Time values for testing
  - Coercing various inputs into Time format
  - Validating Time values

  ## Examples

      iex> alias Estructura.Nested.Type.Time
      iex> Time.validate(~T[10:00:00])
      {:ok, ~T[10:00:00]}

      iex> alias Estructura.Nested.Type.Time
      iex> Time.validate("not a time")
      {:error, "Expected time, got: \\"not a time\\""}

  The type implements the `Estructura.Nested.Type` behaviour, providing:
  - `generate/1` - Creates random Time values for property testing
  - `coerce/1` - Attempts to convert input into a Time
  - `validate/1` - Ensures a value is a valid Time
  """
  @behaviour Estructura.Nested.Type

  @doc """
  Generates random Time values for property-based testing.

  ## Options

  Accepts all options supported by `Estructura.StreamData.time/1`.

  ## Examples

      iex> Time.generate() |> Enum.take(1) |> List.first()
      #Time<...>

      iex> Time.generate(from: ~T[09:00:00], to: ~T[17:00:00]) |> Enum.take(1) |> List.first()
      #Time<...>
  """
  @impl true
  def generate(opts \\ [], _payload \\ []), do: Estructura.StreamData.time(opts)

  @doc """
  Attempts to coerce a value into a Time.

  Delegates to `Estructura.Coercers.Time.coerce/1` which handles various input formats
  including strings in ISO 8601 format and maps with time components.

  ## Examples

      iex> Time.coerce("10:00:00")
      {:ok, ~T[10:00:00]}

      iex> Time.coerce(%{hour: 10, minute: 0, second: 0})
      {:ok, ~T[10:00:00]}

      iex> Time.coerce("invalid")
      {:error, "Invalid Time format"}
  """
  @impl true
  defdelegate coerce(term), to: Estructura.Coercers.Time

  @doc """
  Validates that a term is a valid Time.

  Returns `{:ok, time}` for valid Time values,
  or `{:error, reason}` for invalid ones.

  ## Examples

      iex> Time.validate(~T[10:00:00])
      {:ok, ~T[10:00:00]}

      iex> Time.validate("10:00")
      {:error, "Expected time, got: \\"10:00\\""}
  """
  @impl true
  def validate(%Time{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected time, got: " <> inspect(other)}
end
