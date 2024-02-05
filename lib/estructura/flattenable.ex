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
        if not is_nil(Estructura.Flattenable.impl_for(v)) and v != %{} and v != [] do
          Estructura.Flattenable.flatten(
            v,
            Keyword.put(options, :__acc__, %{key: [k | key], acc: acc})
          )
        else
          Map.put(acc, [k | key] |> Enum.reverse() |> Enum.join(coupler), v)
        end

      %{key: key, acc: acc}
    end)
    |> Map.fetch!(:acc)
    |> Map.filter(&filter(&1, options))
  end
end
