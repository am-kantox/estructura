defmodule Estructura.WIATest do
  use ExUnit.Case, async: true

  alias Estructura.WIA.Test.{Coerced, Plain}

  describe "Plain WIA struct" do
    test "creates struct with defaults" do
      wia = %Plain{}
      assert wia.foo == 42
      assert wia.bar == "hello"
      assert wia.baz == %{}
    end

    test "__fields__/0 returns the field names" do
      assert Plain.__fields__() == [:foo, :bar, :baz]
    end
  end

  describe "Access with atom keys" do
    test "fetch/2 with atom key" do
      wia = %Plain{}
      assert wia[:foo] == 42
      assert wia[:bar] == "hello"
      assert wia[:baz] == %{}
    end

    test "fetch/2 returns nil for unknown atom key" do
      wia = %Plain{}
      assert wia[:unknown] == nil
    end

    test "get_in/2 with atom keys" do
      wia = %Plain{}
      assert get_in(wia, [:foo]) == 42
    end

    test "put_in/3 with atom keys" do
      wia = %Plain{}
      updated = put_in(wia, [:foo], 100)
      assert updated.foo == 100
      assert updated[:foo] == 100
    end

    test "pop_in/2 with atom key" do
      wia = %Plain{foo: 99}
      {value, updated} = pop_in(wia, [:foo])
      assert value == 99
      assert updated.foo == nil
    end
  end

  describe "Indifferent access with binary keys" do
    test "fetch/2 with binary key" do
      wia = %Plain{}
      assert wia["foo"] == 42
      assert wia["bar"] == "hello"
      assert wia["baz"] == %{}
    end

    test "fetch/2 returns nil for unknown binary key" do
      wia = %Plain{}
      assert wia["unknown"] == nil
    end

    test "get_in/2 with binary keys" do
      wia = %Plain{}
      assert get_in(wia, ["foo"]) == 42
    end

    test "put_in/3 with binary keys" do
      wia = %Plain{}
      updated = put_in(wia, ["foo"], 100)
      assert updated.foo == 100
      assert updated["foo"] == 100
      assert updated[:foo] == 100
    end

    test "pop_in/2 with binary key" do
      wia = %Plain{foo: 99}
      {value, updated} = pop_in(wia, ["foo"])
      assert value == 99
      assert updated.foo == nil
    end

    test "put/3 with binary key" do
      wia = %Plain{}
      assert {:ok, updated} = Plain.put(wia, "foo", 100)
      assert updated.foo == 100
    end

    test "get/3 with binary key" do
      wia = %Plain{}
      assert Plain.get(wia, "foo") == 42
      assert Plain.get(wia, "unknown", :default) == :default
    end

    test "atom and binary access return same values" do
      wia = %Plain{foo: 123, bar: "world"}
      assert wia[:foo] == wia["foo"]
      assert wia[:bar] == wia["bar"]
      assert wia[:baz] == wia["baz"]
    end
  end

  describe "Coercion" do
    test "put/3 coerces values" do
      wia = %Coerced{}
      assert {:ok, updated} = Coerced.put(wia, :name, :atom_name)
      assert updated.name == "atom_name"
    end

    test "put_in/3 coerces values through Access" do
      wia = %Coerced{}
      updated = put_in(wia, [:age], "25")
      assert updated.age == 25
    end

    test "put_in/3 coerces via binary keys" do
      wia = %Coerced{}
      updated = put_in(wia, ["age"], "30")
      assert updated.age == 30
    end

    test "coercion error" do
      wia = %Coerced{}
      assert {:error, {:coercion, _}} = Coerced.put(wia, :age, :not_an_age)
    end
  end

  describe "Validation" do
    test "put/3 validates values after coercion" do
      wia = %Coerced{}
      assert {:error, {:validation, _}} = Coerced.put(wia, :age, -5)
    end

    test "put!/3 raises on validation failure" do
      wia = %Coerced{}

      assert_raise Estructura.Error, fn ->
        Coerced.put!(wia, :age, -5)
      end
    end

    test "valid values pass through" do
      wia = %Coerced{}
      assert {:ok, updated} = Coerced.put(wia, :age, 25)
      assert updated.age == 25
    end
  end

  describe "Enumerable protocol" do
    test "Enum.count/1" do
      wia = %Plain{}
      assert Enum.count(wia) == 3
    end

    test "Enum.member?/2" do
      wia = %Plain{foo: 42}
      assert Enum.member?(wia, {:foo, 42})
      refute Enum.member?(wia, {:foo, 99})
    end

    test "Enum.map/2" do
      wia = %Plain{foo: 1, bar: 2, baz: 3}
      result = Enum.map(wia, fn {_k, v} -> v end)
      assert Enum.sort(result) == [1, 2, 3]
    end

    test "Enum.to_list/1 returns keyword-like pairs" do
      wia = %Plain{foo: 42, bar: "hello", baz: %{}}
      list = Enum.to_list(wia)
      assert is_list(list)
      assert {:foo, 42} in list
      assert {:bar, "hello"} in list
      assert {:baz, %{}} in list
    end

    test "Enum.reduce/3" do
      wia = %Plain{foo: 1, bar: 2, baz: 3}

      sum =
        Enum.reduce(wia, 0, fn
          {_k, v}, acc when is_number(v) -> acc + v
          _, acc -> acc
        end)

      assert sum == 6
    end
  end

  describe "Collectable protocol" do
    test "Enum.into/2 collects key-value pairs" do
      wia = %Plain{}
      updated = Enum.into([{:foo, 100}, {"bar", "world"}], wia)
      assert updated.foo == 100
      assert updated.bar == "world"
    end

    test "for comprehension with into:" do
      wia = %Plain{}
      updated = for {k, v} <- [foo: 99, baz: %{a: 1}], into: wia, do: {k, v}
      assert updated.foo == 99
      assert updated.baz == %{a: 1}
    end
  end

  describe "Inspect protocol" do
    test "inspect mimics struct output" do
      wia = %Plain{foo: 42, bar: "hello", baz: %{}}
      inspected = inspect(wia)
      assert inspected =~ "Estructura.WIA.Test.Plain"
      assert inspected =~ "foo:"
      assert inspected =~ "42"
      assert inspected =~ "bar:"
    end
  end

  if Code.ensure_compiled(Jason) == {:module, Jason} do
    describe "Jason.Encoder" do
      test "encodes to JSON" do
        wia = %Plain{foo: 42, bar: "hello", baz: %{key: "value"}}
        {:ok, json} = Jason.encode(wia)
        decoded = Jason.decode!(json)
        assert decoded["foo"] == 42
        assert decoded["bar"] == "hello"
        assert decoded["baz"] == %{"key" => "value"}
      end
    end
  end
end
