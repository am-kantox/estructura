defmodule Estructura.Aston.Test do
  use ExUnit.Case, async: true

  alias Estructura.Aston

  test "coerces valid data" do
    assert {:ok,
            %Aston{
              name: "Bar",
              attributes: %{foo: :bar},
              content: [
                %Aston{
                  name: "Baz.Baz2",
                  attributes: %{},
                  content: [
                    %Aston{name: "Deep1", attributes: %{}, content: []},
                    %Aston{name: "Deep2", attributes: %{}, content: []}
                  ]
                }
              ]
            }} =
             Aston.coerce(%{
               name: "Bar",
               attributes: {:foo, :bar},
               content: %{name: ["Baz", "Baz2"], content: [%{name: "Deep1"}, %{name: "Deep2"}]}
             })
  end

  test "Aston.access/2" do
    aston =
      %Aston{
        name: "Bar",
        attributes: %{foo: :bar},
        content: [
          %Aston{
            name: "Baz",
            attributes: %{},
            content: [
              %Aston{name: "Deep1", attributes: %{}, content: []},
              %Aston{name: "Deep2", attributes: %{}, content: []}
            ]
          }
        ]
      }

    assert [[%Aston{} = deep]] = get_in(aston, Aston.access(aston, ~w|Bar Baz Deep1|))
    assert deep.name == "Deep1"

    assert %Aston{
             name: "Bar",
             attributes: %{foo: :bar},
             content: [
               %Aston{
                 name: "Baz",
                 attributes: %{},
                 content: [
                   %Aston{name: "Deep1", attributes: %{foo: 42}, content: []},
                   %Aston{name: "Deep2", attributes: %{}, content: []}
                 ]
               }
             ]
           } = put_in(aston, Aston.access(aston, ~w|Bar Baz Deep1|) ++ [:attributes], %{foo: 42})
  end

  test "doesn’t coerce invalid data" do
    assert {:error, "Unknown fields: [\"nameQQ\"]"} = Aston.coerce(%{nameQQ: "Bar"})

    assert {:error, "Unknown fields: [\"content.nameQQ\"]"} =
             Aston.coerce(%{name: "Bar", content: %{nameQQ: ""}})

    assert {:error, "Cannot coerce value given for `name` field (%{foo: :bar})"} =
             Aston.coerce(%{name: %{foo: :bar}})

    assert {:error,
            "Unknown fields: [\"content.content.nameA\"]\nUnknown fields: [\"content.content.nameB\"]"} =
             Aston.coerce(%{
               name: "Bar",
               attributes: {:foo, :bar},
               content: %{name: ["Baz", "Baz2"], content: [%{nameA: "Deep1"}, %{nameB: "Deep2"}]}
             })
  end

  test "generates XmlBuilder AST" do
    assert {:ok, tree} =
             Aston.coerce(%{
               name: "Bar",
               attributes: {:foo, :bar},
               content: %{name: ["Baz", "Baz2"], content: [%{name: "Deep1"}, %{name: "Deep2"}]}
             })

    assert {"Bar", %{foo: :bar}, [{"Baz.Baz2", %{}, [{"Deep1", %{}, []}, {"Deep2", %{}, []}]}]} =
             Aston.to_ast(tree)
  end
end
