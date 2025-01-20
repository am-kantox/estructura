defmodule Estructura.Nested.Type.Time do
  @moduledoc """
  `Estructura` type for `Date`
  """
  @behaviour Estructura.Nested.Type

  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.time(opts)

  @impl true
  defdelegate coerce(term), to: Estructura.Coercers.Time

  @impl true
  def validate(%Time{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected date, got: " <> inspect(other)}
end
