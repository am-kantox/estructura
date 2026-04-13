defmodule Estructura.Nested.JsonSchema.Test do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Estructura.Nested.JsonSchema

  describe "to_shape/1 simple types" do
    test "string type" do
      {shape, init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"name" => %{"type" => "string"}}
        })

      assert %{name: :string} = shape
      assert init == %{}
    end

    test "integer type" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"count" => %{"type" => "integer"}}
        })

      assert %{count: :integer} = shape
    end

    test "positive integer via minimum" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"id" => %{"type" => "integer", "minimum" => 1}}
        })

      assert %{id: :positive_integer} = shape
    end

    test "positive integer via exclusiveMinimum" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"id" => %{"type" => "integer", "exclusiveMinimum" => 0}}
        })

      assert %{id: :positive_integer} = shape
    end

    test "number type maps to float" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"score" => %{"type" => "number"}}
        })

      assert %{score: :float} = shape
    end

    test "boolean type" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"active" => %{"type" => "boolean"}}
        })

      assert %{active: :boolean} = shape
    end

    test "null type" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"nothing" => %{"type" => "null"}}
        })

      assert %{nothing: {:constant, nil}} = shape
    end
  end

  describe "to_shape/1 string formats" do
    test "date-time format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"ts" => %{"type" => "string", "format" => "date-time"}}
        })

      assert %{ts: :datetime} = shape
    end

    test "date format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"born" => %{"type" => "string", "format" => "date"}}
        })

      assert %{born: :date} = shape
    end

    test "time format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"at" => %{"type" => "string", "format" => "time"}}
        })

      assert %{at: :time} = shape
    end

    test "uri format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"url" => %{"type" => "string", "format" => "uri"}}
        })

      assert %{url: Estructura.Nested.Type.URI} = shape
    end

    test "uuid format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"uid" => %{"type" => "string", "format" => "uuid"}}
        })

      assert %{uid: Estructura.Nested.Type.UUID} = shape
    end

    test "ipv4 format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"addr" => %{"type" => "string", "format" => "ipv4"}}
        })

      assert %{addr: Estructura.Nested.Type.IP} = shape
    end

    test "ipv6 format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"addr" => %{"type" => "string", "format" => "ipv6"}}
        })

      assert %{addr: Estructura.Nested.Type.IP} = shape
    end

    test "email format" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"email" => %{"type" => "string", "format" => "email"}}
        })

      assert %{email: {:string, kind_of_codepoints: :ascii}} = shape
    end

    test "unknown format falls back to string" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"phone" => %{"type" => "string", "format" => "phone"}}
        })

      assert %{phone: :string} = shape
    end
  end

  describe "to_shape/1 enum" do
    test "string enum" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "status" => %{"type" => "string", "enum" => ["active", "inactive"]}
          }
        })

      assert %{status: {Estructura.Nested.Type.Enum, ["active", "inactive"]}} = shape
    end

    test "integer enum preserves numeric values" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "level" => %{"type" => "integer", "enum" => [1, 2, 3]}
          }
        })

      assert %{level: {Estructura.Nested.Type.Enum, [1, 2, 3]}} = shape
    end
  end

  describe "to_shape/1 nested objects" do
    test "single level nesting" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "address" => %{
              "type" => "object",
              "properties" => %{
                "city" => %{"type" => "string"},
                "zip" => %{"type" => "string"}
              }
            }
          }
        })

      assert %{address: %{city: :string, zip: :string}} = shape
    end

    test "deep nesting" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "address" => %{
              "type" => "object",
              "properties" => %{
                "street" => %{
                  "type" => "object",
                  "properties" => %{
                    "name" => %{"type" => "string"},
                    "number" => %{"type" => "integer"}
                  }
                }
              }
            }
          }
        })

      assert %{address: %{street: %{name: :string, number: :integer}}} = shape
    end

    test "empty object" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"meta" => %{"type" => "object"}}
        })

      assert %{meta: %{}} = shape
    end
  end

  describe "to_shape/1 arrays" do
    test "array of simple type" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
          }
        })

      assert %{tags: [:string]} = shape
    end

    test "array of objects" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "items" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "qty" => %{"type" => "integer"}
                }
              }
            }
          }
        })

      assert %{items: [%{name: :string, qty: :integer}]} = shape
    end

    test "array without items defaults to list of strings" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{"data" => %{"type" => "array"}}
        })

      assert %{data: [:string]} = shape
    end
  end

  describe "to_shape/1 defaults and metadata" do
    test "default values populate init map" do
      {_shape, init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string", "default" => "unknown"},
            "count" => %{"type" => "integer", "default" => 0},
            "score" => %{"type" => "number"}
          }
        })

      assert init == %{name: "unknown", count: 0}
    end

    test "required fields in metadata" do
      {_shape, _init, meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "id" => %{"type" => "integer"},
            "name" => %{"type" => "string"}
          },
          "required" => ["id", "name"]
        })

      assert meta == %{required: [:id, :name]}
    end

    test "title and description in metadata" do
      {_shape, _init, meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "title" => "User",
          "description" => "A user record",
          "properties" => %{"name" => %{"type" => "string"}}
        })

      assert meta == %{title: "User", description: "A user record"}
    end
  end

  describe "to_shape/1 nullable types" do
    test "nullable string collapses to string" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => ["string", "null"]}
          }
        })

      assert %{name: :string} = shape
    end

    test "multi-type without null becomes mixed" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "value" => %{"type" => ["string", "integer"]}
          }
        })

      assert %{value: {:mixed, [:string, :integer]}} = shape
    end
  end

  describe "to_shape/1 $ref resolution" do
    test "resolves $defs reference" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "$defs" => %{
            "address" => %{
              "type" => "object",
              "properties" => %{
                "city" => %{"type" => "string"},
                "zip" => %{"type" => "string"}
              }
            }
          },
          "properties" => %{
            "home" => %{"$ref" => "#/$defs/address"}
          }
        })

      assert %{home: %{city: :string, zip: :string}} = shape
    end

    test "resolves definitions reference" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "definitions" => %{
            "coords" => %{
              "type" => "object",
              "properties" => %{
                "lat" => %{"type" => "number"},
                "lon" => %{"type" => "number"}
              }
            }
          },
          "properties" => %{
            "location" => %{"$ref" => "#/definitions/coords"}
          }
        })

      assert %{location: %{lat: :float, lon: :float}} = shape
    end

    test "resolves $ref in array items" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "$defs" => %{
            "tag" => %{"type" => "string"}
          },
          "properties" => %{
            "tags" => %{
              "type" => "array",
              "items" => %{"$ref" => "#/$defs/tag"}
            }
          }
        })

      assert %{tags: [:string]} = shape
    end

    test "raises on external $ref" do
      assert_raise ArgumentError, ~r/External \$ref not supported/, fn ->
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "ext" => %{"$ref" => "https://example.com/schema.json"}
          }
        })
      end
    end
  end

  describe "to_shape/1 allOf composition" do
    test "merges allOf schemas" do
      {shape, _init, meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "allOf" => [
            %{
              "properties" => %{"name" => %{"type" => "string"}},
              "required" => ["name"]
            },
            %{
              "properties" => %{"age" => %{"type" => "integer"}},
              "required" => ["age"]
            }
          ]
        })

      assert %{name: :string, age: :integer} = shape
      assert Enum.sort(meta.required) == [:age, :name]
    end

    test "allOf with $ref" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "$defs" => %{
            "base" => %{
              "properties" => %{"id" => %{"type" => "integer"}}
            }
          },
          "allOf" => [
            %{"$ref" => "#/$defs/base"},
            %{"properties" => %{"name" => %{"type" => "string"}}}
          ]
        })

      assert %{id: :integer, name: :string} = shape
    end
  end

  describe "to_shape/1 oneOf/anyOf" do
    test "oneOf produces mixed type" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "value" => %{
              "oneOf" => [
                %{"type" => "string"},
                %{"type" => "integer"}
              ]
            }
          }
        })

      assert %{value: {:mixed, [:string, :integer]}} = shape
    end

    test "anyOf with null collapses to single type" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "value" => %{
              "anyOf" => [
                %{"type" => "string"},
                %{"type" => "null"}
              ]
            }
          }
        })

      assert %{value: :string} = shape
    end

    test "anyOf with multiple non-null types" do
      {shape, _init, _meta} =
        JsonSchema.to_shape(%{
          "type" => "object",
          "properties" => %{
            "value" => %{
              "anyOf" => [
                %{"type" => "string"},
                %{"type" => "integer"},
                %{"type" => "null"}
              ]
            }
          }
        })

      assert %{value: {:mixed, [:string, :integer]}} = shape
    end
  end

  describe "to_shape/1 from JSON string" do
    test "parses JSON string" do
      json =
        Jason.encode!(%{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"}
          }
        })

      {shape, _init, _meta} = JsonSchema.to_shape(json)
      assert %{name: :string} = shape
    end

    test "returns error on invalid JSON" do
      assert {:error, {:json_decode, _}} = JsonSchema.to_shape("{invalid")
    end
  end

  describe "to_shape!/1" do
    test "raises on invalid JSON" do
      assert_raise ArgumentError, ~r/Invalid JSON Schema/, fn ->
        JsonSchema.to_shape!("{invalid")
      end
    end

    test "returns result on valid schema" do
      {shape, _init, _meta} =
        JsonSchema.to_shape!(%{
          "type" => "object",
          "properties" => %{"x" => %{"type" => "integer"}}
        })

      assert %{x: :integer} = shape
    end
  end

  # -- Integration tests with compiled modules --------------------------------

  describe "json_schema macro: flat struct" do
    alias Estructura.JsonSchemaFlat

    test "struct has expected fields" do
      flat = %JsonSchemaFlat{}
      assert Map.has_key?(flat, :name)
      assert Map.has_key?(flat, :age)
      assert Map.has_key?(flat, :score)
    end

    test "default values are applied" do
      flat = %JsonSchemaFlat{}
      assert flat.name == "anonymous"
    end

    test "cast from map" do
      assert {:ok, %JsonSchemaFlat{name: "Alice", age: 30, score: 9.5}} =
               JsonSchemaFlat.cast(%{name: "Alice", age: 30, score: 9.5})
    end

    test "Access works" do
      flat = %JsonSchemaFlat{name: "Bob", age: 25, score: 8.0}
      assert get_in(flat, [:name]) == "Bob"
      updated = put_in(flat, [:age], 26)
      assert updated.age == 26
    end
  end

  describe "json_schema macro: nested struct" do
    alias Estructura.JsonSchemaNested

    test "struct has nested sub-modules" do
      nested = %JsonSchemaNested{}
      assert is_struct(nested.address)
      assert is_struct(nested.address.street)
    end

    test "cast from nested map" do
      input = %{
        id: 1,
        name: "Alice",
        address: %{
          city: "Barcelona",
          street: %{name: "La Rambla", house: 42}
        },
        tags: ["dev"],
        status: "active",
        scores: [%{subject: "math", value: 95.5}]
      }

      assert {:ok, result} = JsonSchemaNested.cast(input)
      assert result.name == "Alice"
      assert result.address.city == "Barcelona"
      assert result.address.street.name == "La Rambla"
      assert result.address.street.house == 42
      assert result.tags == ["dev"]
      assert result.status == "active"
      assert [score] = result.scores
      assert score.subject == "math"
      assert score.value == 95.5
    end

    test "enum field coercion works" do
      input = %{
        id: 1,
        name: "Bob",
        status: "inactive"
      }

      assert {:ok, result} = JsonSchemaNested.cast(input)
      assert result.status == "inactive"
    end
  end

  describe "json_schema macro: $ref struct" do
    alias Estructura.JsonSchemaRef

    test "both referenced fields have same structure" do
      ref = %JsonSchemaRef{}
      assert is_struct(ref.home_address)
      assert is_struct(ref.work_address)
      assert Map.has_key?(ref.home_address, :city)
      assert Map.has_key?(ref.home_address, :zip)
      assert Map.has_key?(ref.work_address, :city)
      assert Map.has_key?(ref.work_address, :zip)
    end

    test "cast with $ref fields" do
      input = %{
        name: "Alice",
        home_address: %{city: "Barcelona", zip: "08001"},
        work_address: %{city: "Madrid", zip: "28001"}
      }

      assert {:ok, result} = JsonSchemaRef.cast(input)
      assert result.home_address.city == "Barcelona"
      assert result.work_address.city == "Madrid"
    end
  end

  describe "json_schema macro: JSON round-trip" do
    alias Estructura.JsonSchemaFlat

    test "encode and parse back" do
      original = %JsonSchemaFlat{name: "Test", age: 42, score: 3.14}
      json = Jason.encode!(original)
      assert {:ok, parsed} = JsonSchemaFlat.parse(json)
      assert parsed.name == "Test"
    end
  end

  describe "json_schema macro: generation" do
    alias Estructura.JsonSchemaFlat

    property "generates valid flat structs" do
      check all %JsonSchemaFlat{} = flat <- JsonSchemaFlat.__generator__() do
        assert is_binary(flat.name) or is_nil(flat.name)
        assert is_nil(flat.age) or is_integer(flat.age)
        assert is_nil(flat.score) or is_float(flat.score)
      end
    end
  end
end
