defmodule Estructura.Nested.Type.Date do
  @moduledoc """
  `Estructura` type for `Date`
  """
  @behaviour Estructura.Nested.Type

  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.date(opts)

  @impl true
  defdelegate coerce(term), to: Estructura.Coercers.Date

  @impl true
  def validate(%Date{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected date, got: " <> inspect(other)}
end
