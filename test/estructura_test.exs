defmodule EstructuraTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Estructura
  doctest Estructura.Lazy

  alias Estructura.Collectable.Bitstring, as: ECB
  alias Estructura.Collectable.List, as: ECL
  alias Estructura.Collectable.Map, as: ECM
  alias Estructura.Collectable.MapSet, as: ECMS

  alias Estructura.{Full, LazyInst, Void}
  alias Estructura.Lazy

  require Integer

  @full %Full{}
  @lazy %LazyInst{}
  @void %Void{}

  property "put/3" do
    check all i <- string(?0..?9, min_length: 1) do
      Full.put!(@full, :foo, i) == %Full{@full | foo: String.to_integer(i)}
    end

    assert_raise ArgumentError, ~r/42a is not a valid integer value/, fn ->
      Full.put!(@full, :foo, "42a")
    end

    assert_raise KeyError, "key :not_a_field not found in: Estructura.Full", fn ->
      Full.put!(@full, :not_a_field, 42)
    end
  end

  property "Access" do
    check all j <- integer(), i <- StreamData.constant(if(j < 0, do: -j, else: j)) do
      assert put_in(@full, [:foo], i) == %Full{@full | foo: i}

      assert put_in(@full, [:baz, :inner_baz], i) == %Full{
               @full
               | baz: %{@full.baz | inner_baz: i}
             }

      assert update_in(@full, [:foo], fn _ -> i end) == %Full{@full | foo: i}

      assert update_in(@full, [:baz, :inner_baz], fn _ -> i end) == %Full{
               @full
               | baz: %{@full.baz | inner_baz: i}
             }
    end

    assert pop_in(@full, [:foo]) == {42, %Full{@full | foo: nil}}
    assert pop_in(@full, [:snafu]) == {nil, @full}

    assert_raise UndefinedFunctionError,
                 ~r/Estructura.Void does not implement the Access behaviour/,
                 fn -> pop_in(@void, [:foo]) end

    assert_raise KeyError, "key :not_a_field not found in: Estructura.Full", fn ->
      put_in(@full, [:not_a_field], 42)
    end
  end

  property "Coercion" do
    check all i <- string(?0..?9, min_length: 1) do
      put_in(@full, [:foo], i) == %Full{@full | foo: String.to_integer(i)}
    end

    assert_raise ArgumentError, ~r/42a is not a valid integer value/, fn ->
      put_in(@full, [:foo], "42a")
    end

    assert_raise ArgumentError, ":foo must be positive", fn ->
      put_in(@full, [:foo], -42)
    end
  end

  property "Collectable" do
    check all i <- integer() do
      assert %ECL{into: [^i, ^i]} = Enum.into([i, i], %ECL{})
      assert %ECM{into: %{^i => ^i}} = Enum.into([{i, i}], %ECM{})
      map_set = MapSet.new([i])
      assert %ECMS{into: ^map_set} = Enum.into([i, i], %ECMS{})
      assert %ECB{into: "abc"} = Enum.into(~w[a b c], %ECB{})

      assert_raise Protocol.UndefinedError,
                   ~r/protocol Collectable not implemented for %Estructura.Void/,
                   fn -> Enum.into(~w[a], %Void{}) end
    end
  end

  property "Enumerable" do
    check all i <- integer() do
      assert [^i, ^i, ^i, nil] = Enum.map(%Full{foo: i, bar: i, baz: i}, &elem(&1, 1))

      assert_raise Protocol.UndefinedError,
                   ~r/protocol Enumerable not implemented for %Estructura.Void/,
                   fn -> Enum.map(%Void{}, & &1) end
    end
  end

  property "Generation" do
    check all %Full{foo: foo, bar: bar, baz: baz, zzz: zzz} <- Full.__generator__(%Full{zzz: 42}) do
      assert match?(%{key1: v1, key2: v2} when is_integer(v1) and is_integer(v2), baz)
      assert is_integer(foo)
      assert is_binary(bar)
      assert is_integer(zzz) and Integer.is_even(zzz)
    end

    refute Void.__info__(:functions)[:__generate__]
  end

  test "lazy" do
    lazy = @lazy

    assert %Lazy{} = lazy.foo
    assert 42 = get_in(lazy, [:foo])
    assert {42, data} = pop_in(lazy, [:foo])
    assert %Lazy{value: {:ok, 42}} = data.foo

    now = DateTime.utc_now()
    {value1, lazy} = pop_in(lazy, [:bar])
    assert DateTime.diff(value1, now, :millisecond) < 100
    assert value1 == get_in(lazy, [:bar])
    Process.sleep(110)
    value2 = get_in(lazy, [:bar])
    assert value1 != value2
    assert DateTime.diff(value2, now, :millisecond) > 100
  end
end
