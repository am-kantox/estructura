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

# credo:disable-for-this-file Credo.Check.Design.AliasUsage

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

defmodule Estructura.Coercers.NullableInteger do
  @moduledoc "Nullable coercer for `:integer`, coercing strings and floats by rounding, allows `nil` value"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Integer.coerce(value)
end

defmodule Estructura.Coercers.Float do
  @moduledoc "Default coercer for `:float`, coercing strings and integers by multiplying by `1.0`"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(value) when is_integer(value), do: {:ok, 1.0 * value}

  def coerce(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      {_float, remainder} -> {:error, "Trailing garbage: ‹#{remainder}›"}
      :error -> {:error, "Invalid value: ‹#{inspect(value)}›"}
    end
  end

  def coerce(value) when is_float(value), do: {:ok, value}
end

defmodule Estructura.Coercers.NullableFloat do
  @moduledoc "Nullable coercer for `:float`, coercing strings and floats by rounding, allows `nil` value"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Float.coerce(value)
end

defmodule Estructura.Coercers.Date do
  @moduledoc "Default coercer for `:date`, coercing strings (_ISO8601_) and integers (_epoch_)"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(%Date{} = value), do: {:ok, value}
  def coerce(%DateTime{} = value), do: {:ok, DateTime.to_date(value)}

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

defmodule Estructura.Coercers.NullableDate do
  @moduledoc "Nullable coercer for `:date`, coercing strings and floats by rounding, allows `nil` value"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Date.coerce(value)
end

defmodule Estructura.Coercers.Time do
  @moduledoc "Default coercer for `:time`, coercing strings (_ISO8601_) and integers (_epoch_)"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(%Time{} = value), do: {:ok, value}
  def coerce(%DateTime{} = value), do: {:ok, DateTime.to_time(value)}

  def coerce(<<_::binary-size(2), ?:, _::binary-size(2), ?:, _::binary-size(2)>> = value),
    do: Time.from_iso8601(value)

  def coerce(<<y::binary-size(2), m::binary-size(2), d::binary-size(2)>>),
    do: coerce(y <> <<?:>> <> m <> <<?:>> <> d)

  def coerce(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, value, 0} -> {:ok, DateTime.to_time(value)}
      {:ok, _value, offset} -> {:error, "Unsupported offset: ‹#{offset}›"}
      error -> error
    end
  end
end

defmodule Estructura.Coercers.NullableTime do
  @moduledoc "Nullable coercer for `:time`, coercing strings and floats by rounding, allows `nil` value"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Time.coerce(value)
end

defmodule Estructura.Coercers.Datetime do
  @moduledoc deprecated: "Use `Estructura.Coercers.DateTime` instead"
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

defmodule Estructura.Coercers.DateTime do
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

defmodule Estructura.Coercers.NullableDatetime do
  @moduledoc "Nullable coercer for `:datetime`, coercing strings and floats by rounding, allows `nil` value"

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Datetime.coerce(value)
end
