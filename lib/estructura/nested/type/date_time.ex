defmodule Estructura.Nested.Type.DateTime do
  @moduledoc """
  `Estructura` type for `Date`
  """
  @behaviour Estructura.Nested.Type

  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.datetime(opts)

  @impl true
  defdelegate coerce(term), to: Estructura.Coercers.DateTime

  @impl true
  def validate(%DateTime{} = term), do: {:ok, term}
  def validate(other), do: {:error, "Expected date, got: " <> inspect(other)}
end
