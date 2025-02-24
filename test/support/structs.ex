defmodule Estructura.Void do
  @moduledoc false
  use Estructura, access: false, enumerable: false, collectable: false

  defstruct foo: 0, bar: [], baz: %{inner_baz: 42}, zzz: nil
end

# defmodule Estructura.Calculated do
#   @moduledoc false
#   use Estructura, access: true, enumerable: false, collectable: false, calculated: [foo: "length(bar)"]

#   defstruct foo: 0, bar: [], baz: %{inner_baz: 42}, zzz: nil
# end

defmodule Estructura.LazyInst do
  @moduledoc false
  use Estructura, access: :lazy

  def parse_int(bin), do: with({int, _} <- Integer.parse(bin), do: {:ok, int})
  def current_time("42"), do: {:ok, DateTime.utc_now()}

  defstruct __lazy_data__: "42",
            foo: Estructura.Lazy.new(&Estructura.LazyInst.parse_int/1),
            bar: Estructura.Lazy.new(&Estructura.LazyInst.current_time/1, 100)
end

defmodule Estructura.Full do
  @moduledoc "Full Example"

  @foo_range 0..1_000

  use Estructura,
    access: true,
    coercion: [:foo],
    validation: true,
    enumerable: true,
    collectable: :bar,
    generator: [
      foo: {StreamData, :integer, [@foo_range]},
      bar: {StreamData, :string, [:alphanumeric]},
      baz:
        {StreamData, :fixed_map, [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]},
      zzz: &Estructura.Full.zzz_generator/0
    ]

  defstruct foo: 42, bar: "", baz: %{inner_baz: 42}, zzz: nil

  require Integer

  @doc false
  def zzz_generator do
    StreamData.filter(StreamData.integer(), &Integer.is_even/1)
  end

  @impl Estructura.Full.Coercible
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

  @impl Estructura.Full.Validatable
  def validate_foo(value) when value >= 0, do: {:ok, value}
  def validate_foo(_), do: {:error, ":foo must be positive"}

  @impl Estructura.Full.Validatable
  def validate_bar(value), do: {:ok, value}

  @impl Estructura.Full.Validatable
  def validate_baz(value), do: {:ok, value}

  @impl Estructura.Full.Validatable
  def validate_zzz(value), do: {:ok, value}
end

defmodule Estructura.Collectable.List do
  @moduledoc false
  use Estructura, collectable: :into

  defstruct into: []
end

defmodule Estructura.User do
  @moduledoc """
  Nested example. The source code of the file follows.

  ```elixir
  
  defmodule Calculated do
    @moduledoc false
    def person(this) do
      this.name <> ", " <> this.address.city
    end
  end

  use Estructura.Nested, calculated: [person: &Calculated.person/1]

  shape %{
    created_at: :datetime,
    name: {:string, kind_of_codepoints: Enum.concat([?a..?c, ?l..?o])},
    address: %{city: :string, street: %{name: [:string], house: :string}},
    person: :string,
    homepage: Estructura.Nested.Type.URI,
    ip: Estructura.Nested.Type.IP,
    data: %{age: :float},
    birthday: Estructura.Nested.Type.Date,
    title: {Estructura.Nested.Type.Enum, ~w|junior middle señor|},
    tags: {:tags, ~w|backend frontend|}
  }

  init %{
    name: "Aleksei",
    address: %{city: "Barcelona"}
  }

  coerce do
    def data.age(age) when is_float(age), do: {:ok, age}
    def data.age(age) when is_integer(age), do: {:ok, 1.0 * age}
    def data.age(age) when is_binary(age) do
      age
      |> Float.parse()
      |> case do
        {age, ""} -> {:ok, age}
        {age, _rest} -> {:ok, age}
        :error -> {:ok, 0.0}
      end
    end
  end

  coerce do
    def name(value) when is_binary(value), do: {:ok, value}
    def name(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  end

  validate do
    def address.street.house(house), do: {:ok, house}
  end
  ```

  Now one can cast it from map as below

  ```elixir
  User.cast %{
    address: %{city: "London", street: %{name: "Baker", house: "221 Bis"}},
    data: %{age: 32},
    name: "Watson",
    birthday: "1973-09-30",
    title: "señor",
    tags: ["backend"]}

  {:ok,
     %Estructura.User{
       address: %Estructura.User.Address{
         city: "London",
         street: %Estructura.User.Address.Street{house: "221 Bis", name: "Baker"}
       },
       data: %Estructura.User.Data{age: 32.0},
       name: "Watson",
       person: "Watson, London",
       birthday: ~D[1973-09-30],
       title: "señor",
       tags: ["backend"]}
  ```

  """

  defmodule Calculated do
    @moduledoc false
    def person(this) do
      this.name <> ", " <> this.address.city
    end
  end

  use Estructura.Nested, calculated: [person: &Calculated.person/1]

  shape %{
    created_at: :datetime,
    name: {:string, kind_of_codepoints: Enum.concat([?a..?c, ?l..?o])},
    address: %{city: :string, street: %{name: [:string], house: :positive_integer}},
    person: :string,
    homepage: Estructura.Nested.Type.URI,
    ip: Estructura.Nested.Type.IP,
    data: %{age: :float},
    birthday: Estructura.Nested.Type.Date,
    title: {Estructura.Nested.Type.Enum, ~w|junior middle señor|},
    tags: {Estructura.Nested.Type.Tags, ~w|backend frontend|}
  }

  init %{
    name: "Aleksei",
    address: %{city: "Barcelona"}
  }

  coerce do
    def data.age(age) when is_float(age), do: {:ok, age}
    def data.age(age) when is_integer(age), do: {:ok, 1.0 * age}

    def data.age(age) when is_binary(age) do
      age
      |> Float.parse()
      |> case do
        {age, ""} -> {:ok, age}
        {age, _rest} -> {:ok, age}
        :error -> {:ok, 0.0}
      end
    end
  end

  coerce do
    defdelegate created_at(value), to: :datetime
  end

  validate do
    def address.street.house(house), do: {:ok, house}

    def data.age(age) when age > 0, do: {:ok, age}
    def data.age(age), do: {:error, "Age must be positive, given: #{age}"}
  end
end

defmodule Estructura.Collectable.Map do
  @moduledoc false
  use Estructura, collectable: :into

  defstruct into: %{}
end

defmodule Estructura.Collectable.MapSet do
  @moduledoc false
  use Estructura, collectable: :into

  defstruct into: MapSet.new()
end

defmodule Estructura.Collectable.Bitstring do
  @moduledoc false
  use Estructura, collectable: :into

  defstruct into: ""
end

defmodule Estructura.Diff do
  @moduledoc false

  use Estructura, enumerable: true

  defstruct same: 42, other: :foo, nested: nil
end
