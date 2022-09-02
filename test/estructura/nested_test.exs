defmodule Estructura.Nested.Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Estructura.Nested

  alias Estructura.User
  alias Estructura.User.Data

  require Integer

  @user %User{}

  property "Access" do
    check all i <- float() do
      expected = %User{@user | data: %Data{@user.data | age: i}}

      assert put_in(@user, [:data, :age], i) == expected
      assert update_in(@user, [:data, :age], fn _ -> i end) == expected
    end
  end

  property "Coercion" do
    check all i <- integer() do
      expected = %User{@user | data: %Data{@user.data | age: 1.0 * i}}
      assert put_in(@user, [:data, :age], i) == expected
    end

    check all i <- string(?0..?9, min_length: 1, max_length: 3) do
      expected = %User{@user | data: %Data{@user.data | age: 1.0 * String.to_integer(i)}}
      assert put_in(@user, [:data, :age], i) == expected
    end
  end

  property "Generation" do
    check all %User{} = user <- User.__generator__() do
      assert is_binary(user.name)
      assert is_binary(user.address.city)
      assert is_binary(user.address.street.name)
      assert is_binary(user.address.street.house)
      assert is_float(user.data.age)
    end
  end
end
