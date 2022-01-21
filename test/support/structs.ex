defmodule Estructura.Void do
  @moduledoc false
  use Estructura, access: false, enumerable: false, collectable: false

  defstruct foo: 42, bar: "", baz: %{inner_baz: 42}, zzz: nil
end

defmodule Estructura.Full do
  @moduledoc false

  @foo_range 0..1_000

  use Estructura, access: true, coercion: true, validation: true, enumerable: true, collectable: :bar,
    generator: [
      foo: {StreamData, :integer, [@foo_range]},
      bar: {StreamData, :string, [:alphanumeric]},
      baz: {StreamData, :fixed_map,
        [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]},
      zzz: &Estructura.Full.zzz_generator/0
    ]

  defstruct foo: 42, bar: "", baz: %{inner_baz: 42}, zzz: nil

  require Integer
  def zzz_generator do
    StreamData.filter(StreamData.integer(), &Integer.is_even/1)
  end

  def coerce_foo(value) when is_binary(value) do
    case Integer.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> {:error, "#{value} is not a valid integer value"}
    end
  end

  def validate_foo(value) when value >= 0, do: {:ok, value}
  def validate_foo(_), do: {:error, ":foo must be positive"}
end

defmodule Estructura.Collectable.List do
  @moduledoc false
  use Estructura, collectable: :into

  defstruct into: []
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
