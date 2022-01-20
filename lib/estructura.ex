defmodule Estructura do
  @moduledoc """
  `Estructura` is a set of extensions for Elixir structures,
    such as `Access` implementation, `Enumerable` and `Collectable`
    implementations, validations and test data generation via `StreamData`.
  """

  use Boundary

  @doc false
  defmacro __using__(opts) do
    quote do
      @__estructura__ Map.new(unquote(opts))

      @after_compile Estructura.Hooks
      @before_compile Estructura.Hooks
    end
  end
end
