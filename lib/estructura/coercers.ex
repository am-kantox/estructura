defmodule Estructura.Coercer do
  @moduledoc """
  Behaviour for coercion delegates. Instead of implementing the coercion handlers
    in `Estructura.Nested` inplace, one might do
      
  ```elixir
  coerce do
    defdelegate foo.bar.created_at(value), to: :date
  end
  ```

  Available coercers out of the box:

  - `Estructura.Coercers.Atom`
  - `Estructura.Coercers.Date`
  - `Estructura.Coercers.DateTime`
  - `Estructura.Coercers.Float`
  - `Estructura.Coercers.Integer`
  - `Estructura.Coercers.Time`
  - `Estructura.Coercers.NullableDate`
  - `Estructura.Coercers.NullableDatetime`
  - `Estructura.Coercers.NullableFloat`
  - `Estructura.Coercers.NullableInteger`
  - `Estructura.Coercers.NullableTime`
  """

  @doc "Coerces the input value to the type handled by a respective coercer"
  @callback coerce(value) :: {:ok, value} | {:error, any()} when value: term()
end

# credo:disable-for-this-file Credo.Check.Design.AliasUsage

defmodule Estructura.Coercers.Integer do
  @moduledoc false

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
  @moduledoc false

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Integer.coerce(value)
end

defmodule Estructura.Coercers.Float do
  @moduledoc false

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
  @moduledoc false

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Float.coerce(value)
end

defmodule Estructura.Coercers.Date do
  @moduledoc false

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
  @moduledoc false

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Date.coerce(value)
end

defmodule Estructura.Coercers.Time do
  @moduledoc false

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
  @moduledoc false

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Time.coerce(value)
end

defmodule Estructura.Coercers.Datetime do
  @moduledoc deprecated: "Use `Estructura.Coercers.DateTime` instead"
  @moduledoc false

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
  @moduledoc false

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
  @moduledoc false

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(nil), do: {:ok, nil}
  def coerce(value), do: Estructura.Coercers.Datetime.coerce(value)
end

defmodule Estructura.Coercers.Atom do
  @moduledoc false

  @behaviour Estructura.Coercer
  @impl Estructura.Coercer

  def coerce(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}
  def coerce(value) when is_atom(value), do: {:ok, value}
  def coerce(value), do: {:error, {:unexpected_value, value}}
end
