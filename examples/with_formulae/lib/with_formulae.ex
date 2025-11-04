defmodule WithFormulae do
  use Estructura,
    access: true,
    coercion: [:foo], # requires `c:WithFormulae.Coercible.coerce_foo/1` impl
    validation: true, # requires `c:WithFormulae.Validatable.validate_×××/1` impls
    calculated: [foo: "length(bar)"], # requires `:formulae` dependency
    enumerable: true,
    collectable: :bar,
    generator: [
      foo: {StreamData, :integer},
      bar: {StreamData, :list_of, [{StreamData, :string, [:alphanumeric]}]},
      baz: {StreamData, :fixed_map,
        [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]}
    ]

  defstruct foo: 0, bar: [], baz: %{}

  @impl WithFormulae.Coercible
  def coerce_foo(value) when is_integer(value), do: {:ok, value}
  def coerce_foo(value) when is_float(value), do: {:ok, round(value)}
  def coerce_foo(value) when is_binary(value) do
    case Integer.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> {:error, "#{value} is not a valid integer value"}
    end
  end
  def coerce_foo(value),
    do: {:error, "Cannot coerce value given for `foo` field (#{inspect(value)})"}

  @impl WithFormulae.Validatable
  def validate_foo(value) when value >= 0, do: {:ok, value}
  def validate_foo(_), do: {:error, ":foo must be positive"}

  @impl WithFormulae.Validatable
  def validate_bar(value), do: {:ok, value}

  @impl WithFormulae.Validatable
  def validate_baz(value), do: {:ok, value}
end
