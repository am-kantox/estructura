defmodule Estructura.Nested.Type.ScaffoldTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest Estructura.Nested.Type.Enum
  doctest Estructura.Nested.Type.Tags

  # Test modules for enum scaffolding
  defmodule Status do
    use Estructura.Nested.Type.Enum,
      elements: [:pending, :active, :completed]
  end

  defmodule Priority do
    use Estructura.Nested.Type.Enum,
      elements: [:low, :medium, :high],
      coercer: fn
        str when is_binary(str) -> {:ok, String.to_existing_atom(str)}
        atom when is_atom(atom) -> {:ok, atom}
        other -> {:error, "Cannot coerce #{inspect(other)} to priority"}
      end,
      encoder: fn priority, opts -> Jason.Encode.string(Atom.to_string(priority), opts) end
  end

  # Test modules for tags scaffolding
  defmodule Categories do
    use Estructura.Nested.Type.Tags,
      elements: [:tech, :art, :science]
  end

  defmodule Labels do
    use Estructura.Nested.Type.Tags,
      elements: [:bug, :feature, :docs],
      coercer: fn
        tags when is_list(tags) ->
          {:ok,
           Enum.map(tags, fn
             tag when is_binary(tag) -> String.to_existing_atom(tag)
             tag when is_atom(tag) -> tag
           end)
           |> Enum.uniq()}

        other ->
          {:error, "Cannot coerce #{inspect(other)} to tag list"}
      end,
      encoder: fn tags, opts ->
        Jason.Encode.list(Enum.map(tags, &Atom.to_string/1), opts)
      end
  end

  describe "Enum scaffold" do
    property "generates valid enum values" do
      check all value <- Status.generate() do
        assert value in [:pending, :active, :completed]
        assert {:ok, ^value} = Status.validate(value)
      end
    end

    property "generates filtered enum values" do
      check all value <- Status.generate(only: [:pending, :active]) do
        assert value in [:pending, :active]
        refute value == :completed
      end

      check all value <- Status.generate(except: [:completed]) do
        assert value in [:pending, :active]
        refute value == :completed
      end
    end

    property "validates enum values" do
      check all value <- StreamData.member_of([:pending, :active, :completed]) do
        assert {:ok, ^value} = Status.validate(value)
      end
    end

    test "rejects invalid enum values" do
      assert {:error, message} = Status.validate(:invalid)
      assert message =~ "Expected :invalid to be one of:"
      assert message =~ ":pending"
      assert message =~ ":active"
      assert message =~ ":completed"
    end

    property "coerces values with custom coercer" do
      check all value <- Priority.generate() do
        str_value = Atom.to_string(value)
        assert {:ok, ^value} = Priority.coerce(str_value)
      end
    end

    test "encodes enum values to JSON" do
      assert Jason.encode!(:low) == "\"low\""
      assert Jason.encode!(:medium) == "\"medium\""
      assert Jason.encode!(:high) == "\"high\""
    end
  end

  describe "Tags scaffold" do
    property "generates valid tag lists" do
      check all tags <- Categories.generate() do
        assert is_list(tags)
        assert Enum.all?(tags, &(&1 in [:tech, :art, :science]))
        assert {:ok, ^tags} = Categories.validate(tags)
      end
    end

    property "generates filtered tag lists" do
      check all tags <- Categories.generate(only: [:tech, :art]) do
        assert Enum.all?(tags, &(&1 in [:tech, :art]))
        refute :science in tags
      end

      check all tags <- Categories.generate(except: [:science]) do
        assert Enum.all?(tags, &(&1 in [:tech, :art]))
        refute :science in tags
      end
    end

    property "ensures tag uniqueness" do
      check all tags <- Categories.generate() do
        assert length(tags) == length(Enum.uniq(tags))
      end
    end

    test "validates tag lists" do
      assert {:ok, [:tech, :art]} = Categories.validate([:tech, :art])
      assert {:error, message} = Categories.validate([:invalid])
      assert message =~ "All tags are expected to be one of"
      assert message =~ ":tech"
      assert message =~ ":art"
      assert message =~ ":science"
    end

    property "coerces values with custom coercer" do
      check all tags <- Labels.generate() do
        str_tags = Enum.map(tags, &Atom.to_string/1)
        assert {:ok, ^tags} = Labels.coerce(str_tags)
      end
    end

    test "encodes tag lists to JSON" do
      tags = [:bug, :feature]
      assert Jason.encode!(tags) == "[\"bug\",\"feature\"]"
    end
  end
end
