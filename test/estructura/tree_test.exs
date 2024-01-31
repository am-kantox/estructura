defmodule Estructura.Tree.Test do
  use ExUnit.Case, async: true

  alias Estructura.Tree

  test "coerces valid data" do
    assert {:ok,
            %Tree{
              name: "Bar",
              attributes: %{foo: :bar},
              content: [
                %Tree{
                  name: "Baz.Baz2",
                  attributes: %{},
                  content: [
                    %Tree{name: "Deep2", attributes: %{}, content: []},
                    %Tree{name: "Deep1", attributes: %{}, content: []}
                  ]
                }
              ]
            }} =
             Tree.coerce(%{
               name: "Bar",
               attributes: {:foo, :bar},
               content: %{name: ["Baz", "Baz2"], content: [%{name: "Deep1"}, %{name: "Deep2"}]}
             })
  end

  test "doesn’t coerce invalid data" do
    assert {:error, "Unknown fields: [\"nameQQ\"]"} = Tree.coerce(%{nameQQ: "Bar"})

    assert {:error, "Unknown fields: [\"content.nameQQ\"]"} =
             Tree.coerce(%{name: "Bar", content: %{nameQQ: ""}})

    assert {:error, "Cannot coerce value given for `name` field (%{foo: :bar})"} =
             Tree.coerce(%{name: %{foo: :bar}})

    assert {:error,
            "Unknown fields: [\"content.content.nameA\"]\nUnknown fields: [\"content.content.nameB\"]"} =
             Tree.coerce(%{
               name: "Bar",
               attributes: {:foo, :bar},
               content: %{name: ["Baz", "Baz2"], content: [%{nameA: "Deep1"}, %{nameB: "Deep2"}]}
             })
  end
end
