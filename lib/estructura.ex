defmodule Estructura do
  @moduledoc """
  `Estructura` is a set of extensions for Elixir structures,
    such as `Access` implementation, `Enumerable` and `Collectable`
    implementations, validations and test data generation via `StreamData`.

  `Estructura` simplifies the following

    * `Access` implementation for structs
    * `Enumerable` implementation for structs (as maps)
    * `Collectable` implementation for one of struct’s fields (as `MapSet` does)
    * `StreamData` generation of structs for property-based testing

  ### Use Options

  `use Estructura` accepts four keyword arguments.

    * `access: boolean()` whether to generate the `Access` implementation, default `true`
    * `enumerable: boolean()` whether to generate the `Enumerable` porotocol implementation, default `false`
    * `collectable: false | key()` whether to generate the `Collectable` protocol implementation,
      default `false`; if non-falsey atom is given, it must point to a struct field where `Collectable`
      would collect. Should be one of `list()`, `map()`, `MapSet.t()`, `bitstribg()`
    * `generator: %{optional(key()) => Estructura.generator()}` the instructions for the `__generate__/{0,1}`
      functions that would produce the target structure values suitable for usage in `StreamData` property
      testing; the generated `__generator__/1` function is overwritable.

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

  ### Generation

  If `generator` keyword argument has been passed, `MyStruct.__generate__/{0,1}` can be
  used to generate instances of this struct for `StreamData` property based tests.

  ```elixir
  property "generation" do
    check all %MyStruct{foo: foo, bar: bar, baz: baz} <- MyStruct.__generator__() do
      assert match?(%{key1: v1, key2: v2} when is_integer(v1) and is_integer(v2), baz)
      assert is_integer(foo)
      assert is_binary(bar)
    end
  end
  ```
  """

  use Boundary

  @typedoc "The generator to be passed to `use Estructura` should be given in one of these forms"
  @type generator :: {module(), atom()} | {module(), atom(), [any()]} | (() -> any())

  @doc false
  defmacro __using__(opts) do
    quote do
      @__estructura__ struct!(Estructura.Config, unquote(opts))

      @after_compile Estructura.Hooks
      @before_compile Estructura.Hooks
    end
  end
end
