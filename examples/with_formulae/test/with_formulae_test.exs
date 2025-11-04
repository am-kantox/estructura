defmodule WithFormulaeTest do
  use ExUnit.Case
  doctest WithFormulae

  test "calculated value" do
    wf = %WithFormulae{} |> put_in([:bar], ~w[a b c])
    IO.inspect(wf)
    assert wf.foo == 3
  end
end
