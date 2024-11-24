defmodule Estructura.Flattenable.Test do
  use ExUnit.Case, async: true
  use Mneme

  setup_all do
    nested_map = %{
      level_1_int: 42,
      level_1_float: 3.14159265,
      level_1_string: "string",
      level_1_date: Date.from_iso8601!("2024-11-24"),
      level_1_tuple: Date.from_iso8601("2024-11-24"),
      level_2: [
        level_2_int: 42,
        level_2_string: "string",
        level_2_date: Date.from_iso8601!("2024-11-24")
      ]
    }

    [map: nested_map]
  end

  test "map", %{map: map} do
    assert %{
             "level_1_date" => ~D[2024-11-24],
             "level_1_float" => 3.14159265,
             "level_1_int" => 42,
             "level_1_string" => "string",
             "level_1_tuple" => {:ok, ~D[2024-11-24]},
             "level_2_level_2_date" => ~D[2024-11-24],
             "level_2_level_2_int" => 42,
             "level_2_level_2_string" => "string"
           } == Estructura.Flattenable.flatten(map)
  end

  test "map with option `jsonify: true`", %{map: map} do
    assert %{
             "level_1_date" => "2024-11-24",
             "level_1_float" => 3.14159265,
             "level_1_int" => 42,
             "level_1_string" => "string",
             "level_1_tuple" => "{:ok, ~D[2024-11-24]}",
             "level_2_level_2_date" => "2024-11-24",
             "level_2_level_2_int" => 42,
             "level_2_level_2_string" => "string"
           } == Estructura.Flattenable.flatten(map, jsonify: true)
  end
end
