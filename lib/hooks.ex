defmodule Estructura.Hooks do
  @moduledoc false

  @spec access_ast(boolean(), [atom()]) :: Macro.t()
  defp access_ast(false, _fields), do: []

  defp access_ast(true, fields) when is_list(fields) do
    opening =
      quote do
        @behaviour Access
      end

    clauses =
      for key <- fields do
        quote do
          @impl Access
          def fetch(%__MODULE__{unquote(key) => value}, unquote(key)), do: {:ok, value}

          @impl Elixir.Access
          def pop(%__MODULE__{unquote(key) => value} = data, unquote(key)),
            do: {value, %{data | unquote(key) => nil}}

          @impl Elixir.Access
          def get_and_update(%__MODULE__{unquote(key) => value} = data, unquote(key), fun) do
            case fun.(value) do
              :pop -> pop(data, unquote(key))
              {current_value, new_value} -> {current_value, %{data | unquote(key) => new_value}}
            end
          end
        end
      end

    closing =
      quote do
        @impl Elixir.Access
        def fetch(%__MODULE__{}, _key), do: :error

        @impl Elixir.Access
        def pop(%__MODULE__{} = data, _key), do: {nil, data}

        @impl Elixir.Access
        def get_and_update(%__MODULE__{}, key, _),
          do: raise(KeyError, key: key, term: __MODULE__)
      end

    [opening | clauses] ++ [closing]
  end

  @spec enumerable_ast(boolean(), [atom()]) :: Macro.t()
  defp enumerable_ast(false, _fields), do: []

  defp enumerable_ast(true, fields) when is_list(fields) do
    count = Enum.count(fields)

    quote bind_quoted: [fields: fields, count: count] do
      module = __MODULE__

      defimpl Enumerable, for: __MODULE__ do
        def count(_), do: unquote(count)

        for key <- fields do
          def member?(%unquote(module){} = s, {unquote(key), value}),
            do: {:ok, match?(%{unquote(key) => ^value}, s)}
        end

        def member?(%unquote(module){}, _), do: {:ok, false}

        def slice(%unquote(module){} = s) do
          size = unquote(count)
          list = s |> Map.from_struct() |> :maps.to_list()

          {:ok, size, &Enumerable.List.slice(list, &1, &2, size)}
        end

        def reduce(s, acc, fun) do
          s
          |> Map.from_struct()
          |> :maps.to_list()
          |> Enumerable.List.reduce(acc, fun)
        end
      end
    end
  end

  @spec collectable_ast(atom()) :: Macro.t()
  defp collectable_ast(nil), do: []
  defp collectable_ast(false), do: []

  defp collectable_ast(field) when is_atom(field) do
    quote bind_quoted: [field: field] do
      module = __MODULE__

      defimpl Collectable, for: __MODULE__ do
        def into(%unquote(module){unquote(field) => %MapSet{} = old_value} = s) do
          fun = fn
            list, {:cont, x} ->
              [x | list]

            list, :done ->
              %unquote(module){s | unquote(field) => MapSet.union(old_value, MapSet.new(list))}

            _, :halt ->
              :ok
          end

          {[], fun}
        end

        def into(%unquote(module){unquote(field) => old_value} = s) when is_list(old_value) do
          fun = fn
            list, {:cont, x} ->
              [x | list]

            list, :done ->
              %unquote(module){s | unquote(field) => old_value ++ list}

            _, :halt ->
              :ok
          end

          {[], fun}
        end

        def into(%unquote(module){unquote(field) => %{} = old_value} = s) do
          fun = fn
            list, {:cont, x} ->
              [x | list]

            list, :done ->
              %unquote(module){s | unquote(field) => Map.merge(old_value, Map.new(list))}

            _, :halt ->
              :ok
          end

          {[], fun}
        end

        def into(%unquote(module){unquote(field) => old_value} = s) when is_binary(old_value) do
          fun = fn
            acc, {:cont, x} when is_binary(x) and is_list(acc) ->
              [acc | x]

            acc, {:cont, x} when is_bitstring(x) and is_bitstring(acc) ->
              <<acc::bitstring, x::bitstring>>

            acc, {:cont, x} when is_bitstring(x) ->
              <<IO.iodata_to_binary(acc)::bitstring, x::bitstring>>

            acc, :done when is_bitstring(acc) ->
              %unquote(module){s | unquote(field) => acc}

            acc, :done ->
              %unquote(module){s | unquote(field) => IO.iodata_to_binary(acc)}

            __acc, :halt ->
              :ok
          end

          {[old_value], fun}
        end

        def into(%unquote(module){unquote(field) => old_value} = s)
            when is_bitstring(old_value) do
          fun = fn
            acc, {:cont, x} when is_bitstring(x) ->
              <<acc::bitstring, x::bitstring>>

            acc, :done ->
              %unquote(module){s | unquote(field) => acc}

            _acc, :halt ->
              :ok
          end

          {old_value, fun}
        end
      end
    end
  end

  ##############################################################################

  @spec fields(module()) :: [atom()]
  defp fields(module) do
    module
    |> Module.get_attribute(:__struct__, %{})
    |> Map.delete(:__struct__)
    |> Map.keys()
  end

  def __after_compile__(_env, _bytecode) do
    # IO.inspect(env.module.__struct__, label: "AFTER")
  end

  defmacro __before_compile__(env) do
    module = env.module

    fields = fields(module)

    config = Module.get_attribute(module, :__estructura__)

    access_ast = access_ast(Map.get(config, :access, false), fields)

    enumerable_ast = enumerable_ast(Map.get(config, :enumerable, false), fields)

    field = Map.get(config, :collectable, false)
    if field && field not in fields, do: raise(KeyError, key: field, term: __MODULE__)
    collectable_ast = collectable_ast(field)

    [access_ast, enumerable_ast, collectable_ast]
    |> Enum.map(&List.wrap/1)
    |> Enum.reduce(&Kernel.++/2)
  end
end
