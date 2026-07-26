defmodule Estructura.WIA.Test.Plain do
  @moduledoc false
  use Estructura.WIA,
    fields: [
      foo: [default: 42],
      bar: [default: "hello"],
      baz: [default: %{}]
    ]
end

defmodule Estructura.WIA.Test.Coerced do
  @moduledoc false
  use Estructura.WIA,
    fields: [
      name: [default: "", coerce: true],
      age: [default: 0, coerce: true, validate: true],
      tags: [default: []]
    ]

  @impl __MODULE__.Coercible
  def coerce_name(value) when is_binary(value), do: {:ok, value}
  def coerce_name(value) when is_atom(value), do: {:ok, Atom.to_string(value)}

  def coerce_name(value),
    do: {:error, "Cannot coerce #{inspect(value)} to name"}

  @impl __MODULE__.Coercible
  def coerce_age(value) when is_integer(value), do: {:ok, value}
  def coerce_age(value) when is_float(value), do: {:ok, round(value)}

  def coerce_age(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "#{value} is not a valid integer"}
    end
  end

  def coerce_age(value),
    do: {:error, "Cannot coerce #{inspect(value)} to age"}

  @impl __MODULE__.Validatable
  def validate_age(value) when is_integer(value) and value >= 0, do: {:ok, value}
  def validate_age(value), do: {:error, ":age must be a non-negative integer, got #{inspect(value)}"}
end
