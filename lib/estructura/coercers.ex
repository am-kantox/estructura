defmodule Estructura.Coercer do
  @moduledoc """
  Behaviour for coercion delegates. Instead of implementing the coercion handlers
    in `Estructura.Nested` inplace, one might do
      
  ```elixir
  coerce do
    defdelegate foo.bar.created_at(value), to: :date
  end
  ```
  """
  @callback coerce(value) :: {:ok, value} | {:error, any()} when value: term()
end

defmodule Estructura.Coercers.Integer do
  @moduledoc "Default coercer for `:integer`, coercing strings and floats by rounding"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(value) when is_integer(value), do: {:ok, value}

  def coerce(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      {_int, remainder} -> {:error, "Trailing garbage: ‹#{remainder}›"}
      :error -> {:error, "Invalid value: ‹#{inspect(value)}›"}
    end
  end

  def coerce(value) when is_float(value), do: {:ok, round(value)}
end

defmodule Estructura.Coercers.Date do
  @moduledoc "Default coercer for `:date`, coercing strings (_ISO8601_) and integers (_epoch_)"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(%Date{} = value), do: {:ok, value}

  def coerce(<<_::binary-size(4), ?-, _::binary-size(2), ?-, _::binary-size(2)>> = value),
    do: Date.from_iso8601(value)

  def coerce(<<y::binary-size(4), ?/, m::binary-size(2), ?/, d::binary-size(2)>>),
    do: coerce(y <> <<?->> <> m <> <<?->> <> d)

  def coerce(<<y::binary-size(4), m::binary-size(2), d::binary-size(2)>>),
    do: coerce(y <> <<?->> <> m <> <<?->> <> d)

  def coerce(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, value, 0} -> {:ok, DateTime.to_date(value)}
      {:ok, _value, offset} -> {:error, "Unsupported offset: ‹#{offset}›"}
      error -> error
    end
  end
end

defmodule Estructura.Coercers.Datetime do
  @moduledoc "Default coercer for `:datetime`, coercing strings (_ISO8601_) and integers (_epoch_)"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(%DateTime{} = value), do: {:ok, value}

  def coerce(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, result, 0} -> {:ok, result}
      {:ok, _result, offset} -> {:error, "Unsupported offset (#{offset})"}
      error -> error
    end
  end

  def coerce(value) when is_integer(value) do
    DateTime.from_unix(value)
  end
end
