defmodule Estructura.Nested.Type.IP do
  @moduledoc """
  `Estructura` type for `Date`
  """
  @behaviour Estructura.Nested.Type

  @type t :: %{
          __struct__: __MODULE__,
          type: :v4 | :v6,
          n1: 0..255 | 0..65_535,
          n2: 0..255 | 0..65_535,
          n3: 0..255 | 0..65_535,
          n4: 0..255 | 0..65_535,
          n5: 0..65_535,
          n6: 0..65_535,
          n7: 0..65_535,
          n8: 0..65_535
        }
  defstruct type: :v4, n1: 127, n2: 0, n3: 0, n4: 1, n5: -1, n6: -1, n7: -1, n8: -1

  defmacro sigil_IP({:<<>>, _, [binary]}, _modifiers) when is_binary(binary) do
    quote generated: true, location: :keep do
      case coerce(unquote(binary)) do
        {:ok, %__MODULE__{} = ip} -> ip
        {:error, error} -> raise ArgumentError, message: error
      end
    end
  end

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    def inspect(%Estructura.Nested.Type.IP{type: :v4, n1: n1, n2: n2, n3: n3, n4: n4}, opts) do
      concat([
        "~IP[",
        to_doc(n1, opts),
        ".",
        to_doc(n2, opts),
        ".",
        to_doc(n3, opts),
        ".",
        to_doc(n4, opts),
        "]"
      ])
    end

    def inspect(
          %Estructura.Nested.Type.IP{
            type: :v6,
            n1: n1,
            n2: n2,
            n3: n3,
            n4: n4,
            n5: n5,
            n6: n6,
            n7: n7,
            n8: n8
          },
          opts
        ) do
      concat([
        "~IP[",
        to_doc({n1, n2, n3, n4, n5, n6, n7, n8} |> :inet.ntoa() |> to_string(), opts),
        "]"
      ])
    end
  end

  defimpl Jason.Encoder do
    @moduledoc false
    def encode(%Estructura.Nested.Type.IP{type: :v4, n1: n1, n2: n2, n3: n3, n4: n4}, _opts) do
      [?", Enum.join([n1, n2, n3, n4], "."), ?"]
    end

    def encode(
          %Estructura.Nested.Type.IP{
            type: :v6,
            n1: n1,
            n2: n2,
            n3: n3,
            n4: n4,
            n5: n5,
            n6: n6,
            n7: n7,
            n8: n8
          },
          _opts
        ) do
      [?", {n1, n2, n3, n4, n5, n6, n7, n8} |> :inet.ntoa() |> to_string(), ?"]
    end
  end

  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.ip(opts)

  @impl true
  def coerce(term) when is_binary(term) do
    term
    |> to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, result} -> coerce(result)
      _ -> {:error, "Not valid IP: #{term}"}
    end
  end

  def coerce([n1, n2, n3, n4] = ip4)
      when n1 in 0..255 and n2 in 0..255 and n3 in 0..255 and n4 in 0..255,
      do: ip4 |> List.to_tuple() |> coerce()

  def coerce([n1, n2, n3, n4, n5, n6, n7, n8] = ip6)
      when n1 in 0..65_535 and n2 in 0..65_535 and n3 in 0..65_535 and n4 in 0..65_535 and
             n5 in 0..65_535 and n6 in 0..65_535 and n7 in 0..65_535 and n8 in 0..65_535,
      do: ip6 |> List.to_tuple() |> coerce()

  def coerce({n1, n2, n3, n4})
      when n1 in 0..255 and n2 in 0..255 and n3 in 0..255 and n4 in 0..255,
      do: coerce(%__MODULE__{type: :v4, n1: n1, n2: n2, n3: n3, n4: n4})

  def coerce({n1, n2, n3, n4, n5, n6, n7, n8})
      when n1 in 0..65_535 and n2 in 0..65_535 and n3 in 0..65_535 and n4 in 0..65_535 and
             n5 in 0..65_535 and n6 in 0..65_535 and n7 in 0..65_535 and n8 in 0..65_535,
      do:
        coerce(%__MODULE__{
          type: :v6,
          n1: n1,
          n2: n2,
          n3: n3,
          n4: n4,
          n5: n5,
          n6: n6,
          n7: n7,
          n8: n8
        })

  def coerce(%__MODULE__{type: :v4, n1: n1, n2: n2, n3: n3, n4: n4} = ip4)
      when n1 in 0..255 and n2 in 0..255 and n3 in 0..255 and n4 in 0..255,
      do: {:ok, ip4}

  def coerce(
        %__MODULE__{type: :v6, n1: n1, n2: n2, n3: n3, n4: n4, n5: n5, n6: n6, n7: n7, n8: n8} =
          ip6
      )
      when n1 in 0..65_535 and n2 in 0..65_535 and n3 in 0..65_535 and n4 in 0..65_535 and
             n5 in 0..65_535 and n6 in 0..65_535 and n7 in 0..65_535 and n8 in 0..65_535,
      do: {:ok, ip6}

  def coerce(term), do: {:error, "Not valid IP: " <> inspect(term)}

  @impl true
  def validate(%__MODULE__{type: :v4, n1: n1, n2: n2, n3: n3, n4: n4} = ip4)
      when n1 in 0..255 and n2 in 0..255 and n3 in 0..255 and n4 in 0..255,
      do: {:ok, ip4}

  def validate(
        %__MODULE__{type: :v6, n1: n1, n2: n2, n3: n3, n4: n4, n5: n5, n6: n6, n7: n7, n8: n8} =
          ip6
      )
      when n1 in 0..65_535 and n2 in 0..65_535 and n3 in 0..65_535 and n4 in 0..65_535 and
             n5 in 0..65_535 and n6 in 0..65_535 and n7 in 0..65_535 and n8 in 0..65_535,
      do: {:ok, ip6}

  def validate(other), do: {:error, "Expected IP, got: " <> inspect(other)}
end
