defmodule Estructura.Nested.Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Estructura.Nested
  doctest Estructura.Transformer

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
      assert is_list(user.address.street.name)
      assert Enum.all?(user.address.street.name, &is_binary/1)
      assert is_binary(user.address.street.house)
      assert is_float(user.data.age)
      assert is_struct(user.created_at, DateTime)
      assert is_struct(user.birthday, Date)
    end
  end

  property "Jason encode/decode" do
    check all %User{} = user <- User.__generator__() do
      assert {:ok, user} == User.parse(Jason.encode!(user))
    end
  end

  property "Transformer" do
    check all %User{} = user <- User.__generator__() do
      assert [
               *: Estructura.User,
               address: [
                 *: Estructura.User.Address,
                 city: _,
                 street: [*: Estructura.User.Address.Street, house: _, name: _]
               ],
               birthday: _,
               created_at: _,
               data: [*: Estructura.User.Data, age: _],
               name: _
             ] = Estructura.Transformer.transform(user)
    end

    check all %User{} = user <- User.__generator__() do
      assert [
               address: [
                 street: [house: _, name: _]
               ],
               birthday: _,
               created_at: _,
               data: [age: _],
               name: _
             ] = Estructura.Transformer.transform(user, except: [:city], type: false)
    end

    check all %User{} = user <- User.__generator__() do
      assert [address: [street: [name: _]], data: [age: _], name: _] =
               Estructura.Transformer.transform(user,
                 only: [:name | ~w|address.street data.age|],
                 type: false
               )
    end
  end

  property "Casting" do
    check all %User{} = user <- User.__generator__() do
      raw_user_ok = %{
        name: user.name,
        address: %{
          city: user.address.city,
          street: %{name: user.address.street.name, house: user.address.street.house}
        },
        birthday: user.birthday,
        created_at: user.created_at,
        data: %{age: user.data.age}
      }

      assert {:ok, ^user} = User.cast(raw_user_ok)

      raw_user_ko = %{
        name: user.name,
        address: %{
          ciudad: user.address.city,
          street: %{nombre: user.address.street.name, casa: user.address.street.house}
        },
        birthday: user.birthday,
        created_at: user.created_at,
        data: %{age: user.data.age}
      }

      assert {:error,
              %KeyError{
                key: key,
                term: Estructura.User
              }} = User.cast(raw_user_ko)

      assert Enum.sort(key) == ["address.ciudad", "address.street.casa", "address.street.nombre"]
    end
  end

  property "Guessed Casting" do
    check all %User{} = user <- User.__generator__() do
      raw_user_ok = %{
        name: user.name,
        address_city: user.address.city,
        address_street_name: user.address.street.name,
        address_street_house: user.address.street.house,
        birthday: user.birthday,
        created_at: user.created_at,
        data_age: user.data.age
      }

      assert {:error, %KeyError{}} = User.cast(raw_user_ok)
      assert {:ok, ^user} = User.cast(raw_user_ok, split: true)

      raw_user_ko = %{
        "name" => user.name,
        :addresscity => user.address.city,
        "address_street_nombre" => user.address.street.name,
        "address_street_casa" => user.address.street.house,
        :data_age => user.data.age,
        :created_at => user.created_at,
        "birthday" => user.birthday
      }

      assert {:error,
              %KeyError{
                key: key,
                term: Estructura.User
              }} = User.cast(raw_user_ko, split: true)

      assert Enum.sort(key) == ["address_street_casa", "address_street_nombre", "addresscity"]
    end
  end
end
