defmodule WithFormulaeTest do
  use ExUnit.Case
  doctest WithFormulae

  test "calculated value (`put_in/3`)" do
    wf = %WithFormulae{} |> put_in([:bar], ~w[a b c])
    IO.inspect(wf)
    assert wf.foo == 3
  end

  test "calculated value (`coerce/3`)" do
    {:ok, wf} = Estructura.coerce(WithFormulae, %{bar: ~w[a b c]})
    IO.inspect(wf)
    assert wf.foo == 3
  end
end
