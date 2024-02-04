defmodule Estructura.Flattener do
  @moduledoc false
  def flatten(map_or_kw, acc) do
    map_or_kw
    |> maybe_fix()
    |> Enum.reduce(acc, fn {k, v}, %{acc: acc, coupler: coupler, key: key} ->
      v = maybe_fix(v)

      if is_nil(Enumerable.impl_for(v)) or v == [] or v == %{} do
        %{
          acc: Map.put(acc, [k | key] |> Enum.reverse() |> Enum.join(coupler), v),
          coupler: coupler,
          key: key
        }
      else
        v
        |> flatten(%{acc: acc, coupler: coupler, key: [k | key]})
        |> Map.update!(:key, &tl/1)
      end
    end)
  end

  defp maybe_fix(%_{} = struct) do
    if is_nil(Enumerable.impl_for(struct)) and
         not is_nil(Estructura.Flattenable.impl_for(struct)),
       do: Map.from_struct(struct),
       else: struct
  end

  defp maybe_fix(list) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.map(fn
      {{k, v}, _idx} -> {k, v}
      {v, k} -> {k, v}
    end)
  end

  defp maybe_fix(any), do: any

  def filter({key, _}, options), do: filter(key, options)

  def filter(key, options) do
    coupler = Keyword.get(options, :coupler, "_")
    only = Keyword.get(options, :only, [])
    except = Keyword.get(options, :except, [])

    (only == [] or key in only or Enum.any?(only, &String.starts_with?(key, &1 <> coupler))) and
      not (key in except or Enum.any?(except, &String.starts_with?(key, &1 <> coupler)))
  end
end

defprotocol Estructura.Flattenable do
  @doc """
  The function returning the flattened input.

  This protocol is explicitly handful when deeply nested structs are to be serialized.

  ```elixir
  iex|%_{}|1 ▶ %Estructura.User{}
  %Estructura.User{
    address: %Estructura.User.Address{
      city: nil,
      street: %Estructura.User.Address.Street{house: nil, name: []}
    },
    data: %Estructura.User.Data{age: nil},
    name: nil
  }


  iex|%_{}|2 ▶ Estructura.Flattenable.flatten %Estructura.User{}, coupler: "-", except: ~w|address-street data-age|
  %{"address-city" => nil, "birthday" => nil, "created_at" => nil, "name" => nil}
  iex|%_{}|3 ▶ Estructura.Flattenable.flatten %Estructura.User{}, only: ~w|address_street data_age|
  %{"address_street_house" => nil, "data_age" => nil}
  iex|%_{}|4 ▶ Estructura.Flattenable.flatten %Estructura.User{}, only: ~w|address|
  %{"address_city" => nil, "address_street_house" => nil}
  ```

  To enable it for your struct, use `@derive Estructura.Flattenable` or
    `@derive {Estructura.Flattenable, options}`. `Estructura` implementations derive it be default.
  """

  @spec flatten(t(), keyword()) :: term()
  def flatten(input, options \\ [])
end

defimpl Estructura.Flattenable, for: Any do
  defmacro __deriving__(module, _struct, options) do
    quote do
      defimpl Estructura.Flattenable, for: unquote(module) do
        def flatten(input, options) do
          options = Keyword.merge(unquote(options), options)

          %{
            key: [],
            acc: result
          } =
            input
            |> Map.from_struct()
            |> Estructura.Flattener.flatten(%{
              acc: %{},
              coupler: Keyword.get(options, :coupler, "_"),
              key: []
            })

          Map.filter(result, &Estructura.Flattener.filter(&1, options))
        end
      end
    end
  end

  def flatten(input, _options), do: input
end

defimpl Estructura.Flattenable, for: Atom do
  def flatten(atom, _options) do
    atom
  end
end

defimpl Estructura.Flattenable, for: Integer do
  def flatten(integer, _options) do
    integer
  end
end

defimpl Estructura.Flattenable, for: Float do
  def flatten(float, _options) do
    float
  end
end

defimpl Estructura.Flattenable, for: [List, Map] do
  def flatten(enum, options) do
    %{
      key: [],
      acc: result
    } =
      Estructura.Flattener.flatten(enum, %{
        acc: %{},
        coupler: Keyword.get(options, :coupler, "_"),
        key: []
      })

    Map.filter(result, &Estructura.Flattener.filter(&1, options))
  end
end

defimpl Estructura.Flattenable, for: BitString do
  def flatten(bitstring, _options) do
    bitstring
  end
end

# defimpl Estructura.Flattenable, for: [Date, Time, NaiveDateTime, DateTime] do
#   def flatten(value, _options) do
#     @for.to_iso8601(value)
#   end
# end

# defimpl Estructura.Flattenable, for: Decimal do
#   def flatten(input, _options) do
#     @for.to_string(value)
#   end
# end
