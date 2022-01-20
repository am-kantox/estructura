defmodule Estructura do
  @moduledoc """
  `Estructura` is a set of extensions for Elixir structures,
    such as `Access` implementation, `Enumerable` and `Collectable`
    implementations, validations and test data generation via `StreamData`.

  `Estructura` simplifies the following

    * `Access` implementation for structs
    * `Enumerable` implementation for structs (as maps)
    * `Comparable` implementation for one of struct’s fields (as `MapSet` does)
    * `StreamData` generation of structs for property-based testing

  Typical example of usage would be:

  ```elixir
  defmodule MyStruct do
    use Estructura,
      access: true,
      enumerable: true,
      collectable: :bar,
      generator: [
        foo: {StreamData, :integer},
        bar: {StreamData, :list_of, [{StreamData, :string, [:alphanumeric]}]},
        baz: {StreamData, :fixed_map,
          [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]}
      ]

    defstruct foo: 42, bar: [], baz: %{}
  end
  ```

  The above would allow the following to be done with the structure:

  ```elixir
  s = %MyStruct{}

  put_in s, [:foo], :forty_two
  #⇒ %MyStruct{foo: :forty_two, bar: [], baz: %{}}

  for i <- [1, 2, 3], into: s, do: i
  #⇒ %MyStruct{foo: 42, bar: [1, 2, 3], baz: %{}}

  Enum.map(s, &elem(&1, 1))
  #⇒ [42, [], %{}]

  MyStruct.__generator__() |> Enum.take(3)
  #⇒ [
  #      %MyStruct{bar: [], baz: %{key1: 0, key2: 0}, foo: -1},
  #      %MyStruct{bar: ["g", "xO"], baz: %{key1: -1, key2: -2}, foo: 2},
  #      %MyStruct{bar: ["", "", ""], baz: %{key1: -3, key2: 1}, foo: -1}
  #    ]
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
