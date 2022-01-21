defmodule Estructura.Void do
  @moduledoc false
  use Estructura, access: false, enumerable: false, collectable: false

  defstruct foo: 42, bar: "", baz: %{inner_baz: 42}, zzz: nil
end

defmodule Estructura.Full do
  @moduledoc false
  use Estructura, access: true, enumerable: true, collectable: :bar,
    generator: [
      foo: {StreamData, :integer},
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
