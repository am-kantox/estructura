defprotocol Estructura.Transformer do
  @doc """
  The function returning the transformed input to be used with `Inspect` protocol.
  """
  @spec transform(t(), keyword()) :: term()
  def transform(input, options \\ [])
end

defimpl Estructura.Transformer, for: Any do
  defmacro __deriving__(module, _struct, options) do
    quote do
      defimpl Estructura.Transformer, for: unquote(module) do
        def transform(input, options) do
          options = Keyword.merge(unquote(options), options)
          type = Keyword.get(options, :type, true)

          {onlies, nested_onlies, grouped_nested_onlies} =
            options |> Keyword.get(:only, []) |> split_nesteds()

          {excepts, nested_excepts, grouped_nested_excepts} =
            options |> Keyword.get(:except, []) |> split_nesteds()

          data =
            input
            |> then(fn struct ->
              case onlies ++ Map.keys(grouped_nested_onlies) do
                [] -> Map.from_struct(struct)
                onlies -> Map.take(struct, onlies)
              end
            end)
            |> Map.drop(excepts)
            |> Enum.map(fn {k, v} ->
              options =
                options
                |> Keyword.merge(only: nested_onlies ++ Map.get(grouped_nested_onlies, k, []))
                |> Keyword.merge(except: nested_excepts ++ Map.get(grouped_nested_excepts, k, []))

              {k, Estructura.Transformer.transform(v, options)}
            end)

          case type do
            true ->
              [{:*, unquote(module)} | data]

            name when is_atom(name) and name not in [false, nil] ->
              [{name, unquote(module)} | data]

            false ->
              data
          end
        end

        defp split_nesteds(nesteds) do
          {to_apply, to_propagate} =
            Enum.reduce(nesteds, {[], []}, fn
              elem, {to_apply, to_propagate} when is_atom(elem) ->
                {[elem | to_apply], [elem | to_propagate]}

              elem, {to_apply, to_propagate} when is_binary(elem) ->
                elem
                |> String.split(".", parts: 2)
                |> case do
                  [last] -> {[String.to_atom(last) | to_apply], to_propagate}
                  [key, nested] -> {to_apply, [{String.to_atom(key), nested} | to_propagate]}
                end
            end)

          grouped =
            to_propagate
            |> Enum.reject(&is_atom/1)
            |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

          {to_apply, Enum.filter(to_propagate, &is_atom/1), grouped}
        end
      end
    end
  end

  def transform(input, _options), do: input
end

defimpl Estructura.Transformer, for: Atom do
  def transform(atom, _options) do
    atom
  end
end

defimpl Estructura.Transformer, for: Integer do
  def transform(integer, _options) do
    integer
  end
end

defimpl Estructura.Transformer, for: Float do
  def transform(float, _options) do
    float
  end
end

defimpl Estructura.Transformer, for: [List, Map] do
  def transform(enum, options) do
    only = Keyword.get(options, :only, [])
    except = Keyword.get(options, :except, [])

    for {k, v} <- enum,
        only == [] or k in only,
        k not in except,
        do: {k, Estructura.Transformer.transform(v, options)}
  end
end

defimpl Estructura.Transformer, for: BitString do
  def transform(bitstring, _options) do
    bitstring
  end
end

# defimpl Estructura.Transformer, for: [Date, Time, NaiveDateTime, DateTime] do
#   def transform(input, _options) do
#     @for.to_iso8601(value)
#   end
# end

# defimpl Estructura.Transformer, for: Decimal do
#   def transform(input, _options) do
#     @for.to_string(value)
#   end
# end
