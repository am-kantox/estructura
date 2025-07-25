defmodule Estructura.Nested.Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Estructura.Nested
  doctest Estructura.Transformer

  alias Estructura.User

  require Integer

  @user %User{}

  property "Access" do
    check all i <- float(min: 0.1) do
      expected = %{@user | data: %{@user.data | age: i}}

      assert put_in(@user, [:data, :age], i) == expected
      assert update_in(@user, [:data, :age], fn _ -> i end) == expected
    end
  end

  property "Coercion" do
    check all i <- positive_integer() do
      expected = %{@user | data: %{@user.data | age: 1.0 * i}}
      assert put_in(@user, [:data, :age], i) == expected
    end

    check all i <- string(?0..?9, min_length: 1, max_length: 3) do
      i = "1" <> i

      expected = %{@user | data: %{@user.data | age: 1.0 * String.to_integer(i)}}
      assert put_in(@user, [:data, :age], i) == expected
    end
  end

  property "Generation" do
    check all %User{} = user <- User.__generator__() do
      assert is_binary(user.name)
      assert is_binary(user.address.city)
      assert is_list(user.address.street.name)
      assert Enum.all?(user.address.street.name, &is_binary/1)
      assert is_integer(user.address.street.house) and user.address.street.house > 0
      assert is_float(user.data.age) and user.data.age > 0
      assert is_struct(user.created_at, DateTime)
      assert is_struct(user.birthday, Date)
      assert user.title in ~w|junior middle señor|
      assert is_list(user.tags)
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
                 city: city,
                 street: [*: Estructura.User.Address.Street, house: _, name: _]
               ],
               birthday: _,
               created_at: _,
               data: [*: Estructura.User.Data, age: _],
               homepage: _,
               ip: _,
               name: name,
               person: person,
               tags: _,
               title: _
             ] = Estructura.Transformer.transform(user)

      assert person == "#{name}, #{city}"
    end

    check all %User{} = user <- User.__generator__() do
      assert [
               address: [
                 street: [house: _, name: _]
               ],
               birthday: _,
               created_at: _,
               data: [age: _],
               homepage: _,
               ip: _,
               name: _,
               tags: _
             ] =
               Estructura.Transformer.transform(user,
                 except: [:city, :person, :title],
                 type: false
               )
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
        homepage: user.homepage,
        ip: user.ip,
        created_at: user.created_at,
        data: %{age: user.data.age},
        title: user.title,
        tags: user.tags
      }

      assert {:ok, ^user} = User.cast(raw_user_ok)

      raw_user_ko = %{
        name: user.name,
        address: %{
          ciudad: user.address.city,
          street: %{nombre: user.address.street.name, casa: user.address.street.house}
        },
        birthday: user.birthday,
        homepage: user.homepage,
        ip: user.ip,
        created_at: user.created_at,
        data: %{age: user.data.age},
        title: user.title,
        tags: user.tags
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
        homepage: user.homepage,
        ip: user.ip,
        created_at: user.created_at,
        data_age: user.data.age,
        title: user.title,
        tags: user.tags
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

  property "Flattenable" do
    check all %User{} = user <- User.__generator__() do
      raw_user_flatten =
        raw_user_ok = %{
          name: user.name,
          address_city: user.address.city,
          address_street_name: user.address.street.name,
          address_street_house: user.address.street.house,
          birthday: user.birthday,
          person: user.person,
          homepage: user.homepage,
          ip: user.ip,
          created_at: user.created_at,
          data_age: user.data.age,
          title: user.title,
          tags: user.tags
        }

      raw_user_flatten =
        user.homepage
        |> Enum.with_index()
        |> Enum.reduce(Map.delete(raw_user_flatten, :homepage), fn {hp, idx}, acc ->
          Map.put(acc, :"homepage_#{idx}", to_string(hp))
        end)

      raw_user_flatten =
        user.address.street.name
        |> Enum.with_index()
        |> Enum.reduce(Map.delete(raw_user_flatten, :address_street_name), fn {v, idx}, acc ->
          Map.put(acc, "address_street_name_#{idx}", v)
        end)

      raw_user_flatten =
        user.tags
        |> Enum.with_index()
        |> Enum.reduce(Map.delete(raw_user_flatten, :tags), fn {v, idx}, acc ->
          Map.put(acc, "tags_#{idx}", v)
        end)

      raw_user_flatten =
        raw_user_flatten
        |> Map.new(fn {k, v} -> {to_string(k), v} end)

      assert {:ok, ^user} = User.cast(raw_user_ok, split: true)
      assert ^raw_user_flatten = Estructura.Flattenable.flatten(user)
    end
  end
end
