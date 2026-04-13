defmodule Estructura.Nested.JsonSchema do
  @moduledoc """
  Converts [JSON Schema](https://json-schema.org/) definitions into
  `Estructura.Nested`-compatible shape maps.

  This module provides a bridge between the standard JSON Schema format and
  `Estructura.Nested`, allowing you to define nested structures from JSON Schema
  documents instead of (or in addition to) the manual `shape/1` DSL.

  ## Usage

  The primary entry point is `to_shape/1`, which accepts either a decoded
  JSON Schema map or a raw JSON string:

      iex> schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{
      ...>     "name" => %{"type" => "string"},
      ...>     "age" => %{"type" => "integer"}
      ...>   }
      ...> }
      iex> {shape, init, _meta} = Estructura.Nested.JsonSchema.to_shape(schema)
      iex> shape
      %{name: :string, age: :integer}
      iex> init
      %{}

  Or use it directly in a module definition via the `json_schema/1` macro
  provided by `Estructura.Nested`:

      defmodule MyStruct do
        use Estructura.Nested
        json_schema %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
          }
        }
      end

  ## Type Mapping

  JSON Schema types and formats are mapped to Estructura types as follows:

  - `"string"` -> `:string`
  - `"string"` + `"date-time"` -> `:datetime`
  - `"string"` + `"date"` -> `:date`
  - `"string"` + `"time"` -> `:time`
  - `"string"` + `"uri"` -> `Estructura.Nested.Type.URI`
  - `"string"` + `"uuid"` -> `Estructura.Nested.Type.UUID`
  - `"string"` + `"ipv4"` / `"ipv6"` -> `Estructura.Nested.Type.IP`
  - `"string"` + `"email"` -> `{:string, kind_of_codepoints: :ascii}`
  - `"integer"` -> `:integer` (or `:positive_integer` when `minimum >= 1`)
  - `"number"` -> `:float`
  - `"boolean"` -> `:boolean`
  - `"object"` -> nested `%{...}` map (recurse)
  - `"array"` -> `[:type]` or `[%{...}]`
  - `"enum"` -> `{Estructura.Nested.Type.Enum, values}`
  - `"null"` -> `{:constant, nil}`

  ## Features

  - `$ref` resolution (local JSON Pointer references)
  - `allOf` merging
  - `oneOf` / `anyOf` -> `:mixed` types
  - `default` values -> init map
  - Nullable types (`["string", "null"]`)
  """

  @type shape :: %{required(atom()) => term()}
  @type init :: %{optional(atom()) => term()}
  @type metadata :: %{
          optional(:required) => [atom()],
          optional(:title) => binary(),
          optional(:description) => binary()
        }

  @doc """
  Converts a JSON Schema into a tuple of `{shape, init, metadata}` suitable
  for `Estructura.Nested`.

  Accepts either a decoded map or a raw JSON binary string.

  ## Examples

      iex> schema = %{
      ...>   "type" => "object",
      ...>   "properties" => %{
      ...>     "name" => %{"type" => "string", "default" => "anonymous"},
      ...>     "score" => %{"type" => "number"}
      ...>   },
      ...>   "required" => ["name"]
      ...> }
      iex> {shape, init, meta} = Estructura.Nested.JsonSchema.to_shape(schema)
      iex> shape
      %{name: :string, score: :float}
      iex> init
      %{name: "anonymous"}
      iex> meta
      %{required: [:name]}
  """
  @spec to_shape(map() | binary()) ::
          {shape(), init(), metadata()} | {:error, term()}
  def to_shape(schema) when is_binary(schema) do
    case Jason.decode(schema) do
      {:ok, decoded} -> to_shape(decoded)
      {:error, reason} -> {:error, {:json_decode, reason}}
    end
  end

  def to_shape(%{} = schema) do
    root = schema
    convert_object(schema, root)
  end

  @doc """
  Same as `to_shape/1` but raises on errors.
  """
  @spec to_shape!(map() | binary()) :: {shape(), init(), metadata()} | no_return()
  def to_shape!(schema) do
    case to_shape(schema) do
      {:error, reason} -> raise ArgumentError, "Invalid JSON Schema: #{inspect(reason)}"
      result -> result
    end
  end

  # -- Object conversion (top-level entry) ------------------------------------

  @spec convert_object(map(), map()) :: {shape(), init(), metadata()}
  defp convert_object(schema, root) do
    schema = resolve_composition(schema, root)
    properties = Map.get(schema, "properties", %{})
    required = Map.get(schema, "required", [])

    {shape, init} =
      properties
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce({%{}, %{}}, fn {key, prop_schema}, {shape_acc, init_acc} ->
        atom_key = safe_to_atom(key)
        prop_schema = resolve_refs(prop_schema, root)
        type = convert_type(prop_schema, root)

        shape_acc = Map.put(shape_acc, atom_key, type)

        init_acc =
          case Map.get(prop_schema, "default") do
            nil -> init_acc
            default -> Map.put(init_acc, atom_key, default)
          end

        {shape_acc, init_acc}
      end)

    meta =
      %{}
      |> put_if("required", Enum.map(required, &safe_to_atom/1))
      |> put_if("title", Map.get(schema, "title"))
      |> put_if("description", Map.get(schema, "description"))

    {shape, init, meta}
  end

  # -- Type conversion --------------------------------------------------------

  @spec convert_type(map(), map()) :: term()
  defp convert_type(%{"enum" => values} = schema, _root) when is_list(values) do
    type = Map.get(schema, "type")

    casted_values =
      case type do
        t when t in ["integer", "number"] -> values
        _ -> Enum.map(values, &to_string/1)
      end

    {Estructura.Nested.Type.Enum, casted_values}
  end

  defp convert_type(%{"type" => types} = schema, root) when is_list(types) do
    non_null = Enum.reject(types, &(&1 == "null"))

    case non_null do
      [single] ->
        convert_type(Map.put(schema, "type", single), root)

      multiple ->
        {:mixed, Enum.map(multiple, &convert_type(Map.put(schema, "type", &1), root))}
    end
  end

  defp convert_type(%{"type" => "string", "format" => format}, _root) do
    string_format_type(format)
  end

  defp convert_type(%{"type" => "string"}, _root), do: :string

  defp convert_type(%{"type" => "integer"} = schema, _root) do
    min = Map.get(schema, "minimum")
    exclusive_min = Map.get(schema, "exclusiveMinimum")

    cond do
      is_number(min) and min >= 1 -> :positive_integer
      is_number(exclusive_min) and exclusive_min >= 0 -> :positive_integer
      true -> :integer
    end
  end

  defp convert_type(%{"type" => "number"}, _root), do: :float

  defp convert_type(%{"type" => "boolean"}, _root), do: :boolean

  defp convert_type(%{"type" => "null"}, _root), do: {:constant, nil}

  defp convert_type(%{"type" => "object", "properties" => _} = schema, root) do
    {nested_shape, _init, _meta} = convert_object(schema, root)
    nested_shape
  end

  defp convert_type(%{"type" => "object"}, _root), do: %{}

  defp convert_type(%{"type" => "array", "items" => items}, root) do
    items = resolve_refs(items, root)

    case items do
      %{"type" => "object", "properties" => _} ->
        {nested_shape, _init, _meta} = convert_object(items, root)
        [nested_shape]

      _ ->
        [convert_type(items, root)]
    end
  end

  defp convert_type(%{"type" => "array"}, _root), do: [:string]

  # Composition keywords without explicit type
  defp convert_type(%{"allOf" => _} = schema, root) do
    merged = resolve_composition(schema, root)
    convert_type(merged, root)
  end

  defp convert_type(%{"oneOf" => variants}, root) do
    types = Enum.map(variants, &convert_type(resolve_refs(&1, root), root))
    {:mixed, types}
  end

  defp convert_type(%{"anyOf" => variants}, root) do
    non_null =
      Enum.reject(variants, fn
        %{"type" => "null"} -> true
        _ -> false
      end)

    case non_null do
      [single] -> convert_type(resolve_refs(single, root), root)
      multiple -> {:mixed, Enum.map(multiple, &convert_type(resolve_refs(&1, root), root))}
    end
  end

  # $ref at type level
  defp convert_type(%{"$ref" => _} = schema, root) do
    convert_type(resolve_refs(schema, root), root)
  end

  # Fallback
  defp convert_type(_schema, _root), do: :string

  # -- String formats ---------------------------------------------------------

  @spec string_format_type(binary()) :: term()
  defp string_format_type("date-time"), do: :datetime
  defp string_format_type("date"), do: :date
  defp string_format_type("time"), do: :time
  defp string_format_type("uri"), do: Estructura.Nested.Type.URI
  defp string_format_type("uri-reference"), do: Estructura.Nested.Type.URI
  defp string_format_type("uuid"), do: Estructura.Nested.Type.UUID
  defp string_format_type("ipv4"), do: Estructura.Nested.Type.IP
  defp string_format_type("ipv6"), do: Estructura.Nested.Type.IP
  defp string_format_type("email"), do: {:string, kind_of_codepoints: :ascii}
  defp string_format_type(_), do: :string

  # -- $ref resolution --------------------------------------------------------

  @spec resolve_refs(map(), map()) :: map()
  defp resolve_refs(%{"$ref" => ref} = schema, root) do
    resolved = resolve_pointer(ref, root)
    # Merge any sibling keywords (JSON Schema 2019-09+) with resolved
    siblings = Map.delete(schema, "$ref")

    if map_size(siblings) > 0,
      do: Map.merge(resolved, siblings),
      else: resolved
  end

  defp resolve_refs(schema, _root), do: schema

  @spec resolve_pointer(binary(), map()) :: map()
  defp resolve_pointer("#/" <> path, root) do
    segments = String.split(path, "/")

    Enum.reduce(segments, root, fn segment, acc ->
      segment = unescape_json_pointer(segment)

      case acc do
        %{^segment => value} -> value
        _ -> raise ArgumentError, "Cannot resolve JSON Pointer: #/#{path}"
      end
    end)
  end

  defp resolve_pointer("#" <> _, _root) do
    raise ArgumentError, "Only JSON Pointer fragment references (#/...) are supported"
  end

  defp resolve_pointer(ref, _root) do
    raise ArgumentError, "External $ref not supported: #{ref}"
  end

  @spec unescape_json_pointer(binary()) :: binary()
  defp unescape_json_pointer(segment) do
    segment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  # -- Composition resolution -------------------------------------------------

  @spec resolve_composition(map(), map()) :: map()
  defp resolve_composition(%{"allOf" => schemas} = schema, root) when is_list(schemas) do
    base = Map.drop(schema, ["allOf"])

    Enum.reduce(schemas, base, fn sub_schema, acc ->
      sub_schema = resolve_refs(sub_schema, root)
      sub_schema = resolve_composition(sub_schema, root)
      merge_schemas(acc, sub_schema)
    end)
  end

  defp resolve_composition(schema, _root), do: schema

  @spec merge_schemas(map(), map()) :: map()
  defp merge_schemas(a, b) do
    props_a = Map.get(a, "properties", %{})
    props_b = Map.get(b, "properties", %{})
    req_a = Map.get(a, "required", [])
    req_b = Map.get(b, "required", [])

    merged =
      a
      |> Map.merge(b, fn
        "properties", v1, v2 -> Map.merge(v1, v2)
        "required", v1, v2 -> Enum.uniq(v1 ++ v2)
        _key, _v1, v2 -> v2
      end)

    merged
    |> Map.put("properties", Map.merge(props_a, props_b))
    |> Map.put("required", Enum.uniq(req_a ++ req_b))
  end

  # -- Helpers ----------------------------------------------------------------

  @spec safe_to_atom(binary()) :: atom()
  defp safe_to_atom(key) when is_binary(key) do
    key
    |> Macro.underscore()
    |> String.to_atom()
  end

  @spec put_if(map(), binary(), term()) :: map()
  defp put_if(map, _key, nil), do: map
  defp put_if(map, _key, []), do: map
  defp put_if(map, key, value), do: Map.put(map, safe_to_atom(key), value)
end
