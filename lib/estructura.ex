defmodule Estructura do
  @moduledoc """
  `Estructura` is a set of extensions for Elixir structures,
    such as `Access` implementation, `Enumerable` and `Collectable`
    implementations, validations and test data generation via `StreamData`.

  `Estructura` simplifies the following

    * `Access` implementation for structs
    * `Enumerable` implementation for structs
    * `Comparable` implementation for structs
    * `StreamData` generation of structs for property-based testing

  Typical example of usage would be:

  ```elixir
  defmodule MyStruct do
    use Estructura,
      access: true,
      enumerable: true,
      collectable: true,
      generator: [
        foo: {StreamData, :integer},
        bar: {StreamData, :list_of, [:alphanumeric]},
        baz: {StreamData, :fixed_map,
          [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]}
      ]

    defstruct foo: 42, bar: [], baz: %{}
  end
  ```
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
