defmodule Estructura.Void do
  use Estructura, access: false, enumerable: false, collectable: false

  defstruct foo: 42, bar: "", baz: %{inner_baz: 42}, zzz: nil
end

defmodule Estructura.Full do
  use Estructura, access: true, enumerable: true, collectable: :bar

  defstruct foo: 42, bar: "", baz: %{inner_baz: 42}, zzz: nil
end

defmodule Estructura.Collectable.List do
  use Estructura, collectable: :into

  defstruct into: []
end

defmodule Estructura.Collectable.Map do
  use Estructura, collectable: :into

  defstruct into: %{}
end

defmodule Estructura.Collectable.MapSet do
  use Estructura, collectable: :into

  defstruct into: MapSet.new()
end

defmodule Estructura.Collectable.Bitstring do
  use Estructura, collectable: :into

  defstruct into: ""
end
