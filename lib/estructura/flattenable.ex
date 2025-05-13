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

  iex|%_{}|2 ▶ Estructura.Flattenable.flatten(%Estructura.User{}, coupler: "-", except: ~w|address-street data-age|)
  %{"address-city" => nil, "birthday" => nil, "created_at" => nil, "name" => nil}
  iex|%_{}|3 ▶ Estructura.Flattenable.flatten(%Estructura.User{}, only: ~w|address_street data_age|)
  %{"address_street_house" => nil, "data_age" => nil}
  iex|%_{}|4 ▶ Estructura.Flattenable.flatten(%Estructura.User{}, only: ~w|address|)
  %{"address_city" => nil, "address_street_house" => nil}
  ```

  Allowed options are:

  - **`coupler`** the string to concatenate nested keys with, _default:_ **`-`** 
  - **`only`** the list of keys to select
  - **`except`** the list of keys to ignore
  - **`jsonify`** `true` or a json encoder implementation; if set, the values will be jsonified

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
          options =
            unquote(options)
            |> Keyword.merge(options)
            |> Keyword.update(:only, [], fn only -> Enum.map(only, &to_string/1) end)
            |> Keyword.update(:except, [], fn except -> Enum.map(except, &to_string/1) end)

          input
          |> Map.from_struct()
          |> Estructura.Flattenable.flatten(options)
        end
      end
    end
  end

  def flatten(input, _options), do: input
end

defimpl Estructura.Flattenable, for: List do
  def flatten(enum, options) do
    enum
    |> Keyword.keyword?()
    |> if(do: enum, else: enum |> Enum.with_index() |> Enum.map(fn {v, idx} -> {idx, v} end))
    |> Map.new()
    |> Estructura.Flattenable.flatten(options)
  end
end

defimpl Estructura.Flattenable, for: Map do
  defp filter({key, _}, options), do: filter(key, options)

  defp filter(key, options) do
    coupler = Keyword.get(options, :coupler, "_")
    only = Keyword.get(options, :only, [])
    except = Keyword.get(options, :except, [])

    (only == [] or key in only or Enum.any?(only, &String.starts_with?(key, &1 <> coupler))) and
      not (key in except or Enum.any?(except, &String.starts_with?(key, &1 <> coupler)))
  end

  def flatten(map, options) do
    coupler = Keyword.get(options, :coupler, "_")
    outer_acc = Keyword.get(options, :__acc__, %{key: [], acc: %{}})

    map
    |> Enum.reduce(outer_acc, fn {k, v}, %{key: key, acc: acc} ->
      acc =
        cond do
          v == %{} or v == [] ->
            acc

          not is_nil(Estructura.Flattenable.impl_for(v)) ->
            value =
              Estructura.Flattenable.flatten(
                v,
                Keyword.put(options, :__acc__, %{key: [k | key], acc: acc})
              )

            if is_nil(Estructura.Flattenable.impl_for(value)),
              do: Map.put(acc, [k | key] |> Enum.reverse() |> Enum.join(coupler), value),
              else: value

          true ->
            value =
              options
              |> Keyword.get(:jsonify, false)
              |> handle_jsonify(v)

            Map.put(acc, [k | key] |> Enum.reverse() |> Enum.join(coupler), value)
        end

      %{key: key, acc: acc}
    end)
    |> Map.fetch!(:acc)
    |> Map.filter(&filter(&1, options))
  end

  @spec handle_jsonify(nil | boolean() | module(), value) :: String.t() | value when value: term()
  defp handle_jsonify(nil, v), do: v
  defp handle_jsonify(false, v), do: v
  defp handle_jsonify(_, v) when is_atom(v) or is_integer(v) or is_float(v), do: v
  defp handle_jsonify(true, v), do: handle_jsonify(Jason, v)

  defp handle_jsonify(jsonifier, v) when is_atom(jsonifier) do
    case jsonifier.encode(v) do
      {:ok, json} -> jsonifier.decode!(json)
      _ -> inspect(v)
    end
  end
end
