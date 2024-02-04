defmodule Estructura do
  @moduledoc ~S"""
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

    * `access: true | false | :lazy` whether to generate the `Access` implementation, default `true`;
      when `true` or `:lazy`, it also produces `put/3` and `get/3` methods to be used with `coercion`
      and `validation`, when `:lazy`, instances of `Estructura.Lazy` are understood as values
    * `coercion: boolean() | [key()]` whether to generate the bunch of `coerce_×××/1` functions
      to be overwritten by implementations, default `false`
    * `validation: boolean() | [key()]` whether to generate the bunch of `validate_×××/1` functions
      to be overwritten by implementations, default `false`
    * `enumerable: boolean()` whether to generate the `Enumerable` porotocol implementation, default `false`
    * `collectable: false | key()` whether to generate the `Collectable` protocol implementation,
      default `false`; if non-falsey atom is given, it must point to a struct field where `Collectable`
      would collect. Should be one of `list()`, `map()`, `MapSet.t()`, `bitstribg()`
    * `generator: %{optional(key()) => Estructura.Config.generator()}` the instructions
      for the `__generate__/{0,1}` functions that would produce the target structure values suitable
      for usage in `StreamData` property testing; the generated `__generator__/1` function is overwritable.

  Please note, that setting `coercion` and/or `validation` to truthy values has effect
    if and only if `access` has been also set to `true`.

  Typical example of usage would be:

  ```elixir
  defmodule MyStruct do
    use Estructura,
      access: true,
      coercion: [:foo], # requires `c:MyStruct.Coercible.coerce_foo/1` impl
      validation: true, # requires `c:MyStruct.Validatable.validate_×××/1` impls
      enumerable: true,
      collectable: :bar,
      generator: [
        foo: {StreamData, :integer},
        bar: {StreamData, :list_of, [{StreamData, :string, [:alphanumeric]}]},
        baz: {StreamData, :fixed_map,
          [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]}
      ]

    defstruct foo: 42, bar: [], baz: %{}

    @impl MyStruct.Coercible
    def coerce_foo(value) when is_integer(value), do: {:ok, value}
    def coerce_foo(value) when is_float(value), do: {:ok, round(value)}
    def coerce_foo(value) when is_binary(value) do
      case Integer.parse(value) do
        {value, ""} -> {:ok, value}
        _ -> {:error, "#{value} is not a valid integer value"}
      end
    end
    def coerce_foo(value),
      do: {:error, "Cannot coerce value given for `foo` field (#{inspect(value)})"}

    @impl MyStruct.Validatable
    def validate_foo(value) when value >= 0, do: {:ok, value}
    def validate_foo(_), do: {:error, ":foo must be positive"}

    @impl MyStruct.Validatable
    def validate_bar(value), do: {:ok, value}

    @impl MyStruct.Validatable
    def validate_baz(value), do: {:ok, value}
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

  ### Coercion

  When `coercion: true | [key()]` is passed as an argument to `use Estructura`,
  the nested behaviour `Coercible` is generated and the target module claims to implement it.

  To make a coercion work with `MyStruct.put/3` and `put_in/3` provided
  by `Access` implementation, the consumer module should implement `MyStruct.Coercible`
  behaviour.

  For the consumer convenience, the warnings for not implemented functions will be issued by compiler.

  ### Validation

  When `validation: true | [key()]` is passed as an argument to `use Estructura`,
  the nested behaviour `Validatable` is generated and the target module claims to implement it.

  To make a validation work with `MyStruct.put/3` and `put_in/3` provided
  by `Access` implementation, the consumer module should implement `MyStruct.Validatable`
  behaviour.

  For the consumer convenience, the warnings for not implemented functions will be issued by compiler.

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

  ### Lazy

  If `access: :lazy` is passed as an option, the struct content might be instantiated lazily,
  upon first access through `Kernel.×××_in/{2,3}` family.

  This might be explicitly helpful when the real content requires a significant time
  to load and/or store. Consider the full response from the web server, including
  the gzipped content, which might in turn be a huge text file. Or an attachment to an email.

  Instead of unarchiving the content, one might use `Lazy` as

  ```elixir
  defmodule Response do
    @moduledoc false
    use Estructura, access: :lazy

    def extract(file), do: {:ok, ZipHelper.unzip(file)}

   defstruct __lazy_data__: nil,
     file: Estructura.Lazy.new(&Response.extract/1)
  end

  response = %Response{__lazy_data__: zipped_content}
  # immediate response

  response |> get_in([:file])
  # unzip and return

  {unzipped, struct_with_cached_value} = response |> pop_in([:file])
  # unzip and return the value, alter the struct with it
  ```

  See `Estructura.Lazy` for details and options, see `Estructura.LazyMap` for
  the implementation of lazy map.
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      estructura = struct!(Estructura.Config, unquote(opts))

      Module.register_attribute(__MODULE__, :__estructura__,
        accumulate: false,
        persist: true
      )

      Module.put_attribute(__MODULE__, :__estructura__, estructura)

      @before_compile {Estructura.Hooks, :inject_estructura}
      if estructura.access == :lazy and
           is_nil(Enum.find(Module.get_attribute(__MODULE__, :derive), &match?({Inspect, _}, &1))) do
        @derive {Inspect, except: [:__lazy_data__]}
      end

      @derive {Estructura.Transformer, except: [:__lazy_data__]}
    end
  end

  @typedoc "Diff return type"
  @type diff_result :: :diff | :overlap | :disjoint

  @doc """
  Calculates the difference between two estructures and returns a tuple with
    the first element containing same values and the second one with diffs.

  This function accepts maps but this options should be used as a last resort
  because structs are 4–6 times faster.

  ## Examples

  ```elixir
  defmodule M do
    use Estructura, enumerable: true
    defstruct a: true, b: false
  end
  Estructura.diff(struct(M, []), struct(M, b: true), :diff)
  #⇒{%{a: true}, %{b: [false, true]}}

  Estructura.diff(%{a: true, b: false}, %{a: true, b: true}, :overlap)
  #⇒ %{a: true}

  Estructura.diff(%{a: true, b: false}, %{a: true, b: true}, :disjoint)
  #⇒ %{b: [false, true]}
  ```
  """
  @spec diff(map() | struct(), map() | struct(), :diff) :: {map(), map()}
  @spec diff(map() | struct(), map() | struct(), :overlap | :disjoint) :: map()
  def diff(s1, s2, type \\ :disjoint)

  def diff(%mod{} = s1, %mod{} = s2, type) do
    s1
    |> Enumerable.impl_for()
    |> is_nil()
    |> if do
      [m1, m2] = Enum.map([s1, s2], &Map.from_struct/1)
      diff(m1, m2, type)
    else
      s1
      |> Enum.zip(s2)
      |> Enum.reduce({%{}, %{}}, fn
        {{key, value}, {key, value}}, {same, diff} ->
          {Map.put(same, key, value), diff}

        {{key, %mod{} = v1}, {key, %mod{} = v2}}, {same, diff} ->
          {same, Map.put(diff, key, diff(v1, v2, type))}

        {{key, v1}, {key, v2}}, {same, diff} ->
          {same, Map.put(diff, key, [v1, v2])}
      end)
      |> diff_result(type)
    end
  end

  def diff(%_m1{} = s1, %_m2{} = s2, type),
    do: diff(Map.from_struct(s1), Map.from_struct(s2), type)

  def diff(%_m1{} = s1, %{} = m2, type), do: diff(Map.from_struct(s1), m2, type)
  def diff(%{} = m1, %_m2{} = s2, type), do: diff(m1, Map.from_struct(s2), type)

  def diff(%{} = m1, %{} = m2, type) do
    keys = Enum.uniq(Map.keys(m1) ++ Map.keys(m2))

    keys
    |> Enum.reduce({%{}, %{}}, fn key, {same, diff} ->
      {Map.get(m1, key), Map.get(m2, key)}
      |> case do
        {v, v} -> {Map.put(same, key, v), diff}
        {%{} = v1, %{} = v2} -> {same, Map.put(diff, key, diff(v1, v2, type))}
        {v1, v2} -> {same, Map.put(diff, key, [v1, v2])}
      end
    end)
    |> diff_result(type)
  end

  @doc """
  Instantiates the struct by using `Access` from a map, passing all coercions and validations.
  """
  @spec coerce(module(), map(), keyword()) :: {:ok, struct()} | {:error, Exception.t()}
  def coerce(module, %{} = map, options \\ []) when is_atom(module),
    do: Estructura.Nested.from_term(module, map, options)

  @spec diff_result({map(), map()}, :overlap | :disjoint) :: map()
  defp diff_result({same, diff}, :overlap),
    do: for({k, %{} = ok} <- diff, into: same, do: {k, ok})

  defp diff_result({_, result}, :disjoint), do: result
  @spec diff_result({map(), map()}, :diff) :: {map(), map()}
  defp diff_result(result, _diff), do: result
end
