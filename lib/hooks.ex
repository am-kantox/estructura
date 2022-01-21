defmodule Estructura.Hooks do
  @moduledoc false

  @spec access_ast(boolean(), [atom()]) :: Macro.t()
  defp access_ast(false, _fields), do: []

  defp access_ast(true, fields) when is_list(fields) do
    opening =
      quote generated: true, location: :keep do
        @behaviour Access
      end

    clauses =
      for key <- fields do
        quote generated: true, location: :keep do
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
      quote generated: true, location: :keep do
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

    quote generated: true, location: :keep, bind_quoted: [fields: fields, count: count] do
      module = __MODULE__

      defimpl Enumerable, for: __MODULE__ do
        def count(_), do: {:ok, unquote(count)}

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

  @spec collectable_ast(false | atom()) :: Macro.t()
  defp collectable_ast(false), do: []

  defp collectable_ast(field) when is_atom(field) do
    quote generated: true, location: :keep, bind_quoted: [field: field] do
      module = __MODULE__

      defimpl Collectable, for: __MODULE__ do
        @dialyzer {:nowarn_function, into: 1}

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

  @spec generator_ast(false | keyword()) :: Macro.t()
  defp generator_ast(false), do: []

  if match?({:module, StreamData}, Code.ensure_compiled(StreamData)) do
    defp generator_ast([{_, _} | _] = types) do
      types = Macro.escape(types)

      quote generated: true, location: :keep, bind_quoted: [types: types] do
        module = __MODULE__

        @__generator__ %{types: types, fields: Keyword.keys(types)}

        defp fix_gen(many) when is_list(many), do: Enum.map(many, &fix_gen/1)

        defp fix_gen(capture) when is_function(capture, 0),
          do: with(info <- Function.info(capture), do: fix_gen({info[:module], info[:name]}))

        defp fix_gen({key, {mod, fun, args} = value})
             when is_atom(mod) and is_atom(fun) and is_list(args),
             do: {key, fix_gen(value)}

        defp fix_gen({key, {mod, fun}}) when is_atom(mod) and is_atom(fun),
          do: fix_gen({key, {mod, fun, []}})

        defp fix_gen({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args) do
          {{:., [], [mod, fun]}, [], fix_gen(args)}
        end

        defp fix_gen({mod, fun}) when is_atom(mod) and is_atom(fun), do: fix_gen({mod, fun, []})
        defp fix_gen(value), do: value

        # @dialyzer {:nowarn_function, generation_leaf: 1}
        defp generation_leaf(args),
          do: {{:., [], [StreamData, :constant]}, [], [{:{}, [], args}]}

        defp generation_clause({arg, gen}, acc) do
          {{:., [], [StreamData, :bind]}, [], [gen, {:fn, [], [{:->, [], [[arg], acc]}]}]}
        end

        defp generation_bound do
          args =
            Enum.map(@__generator__.types, fn {arg, gen} ->
              {Macro.var(arg, nil), fix_gen(gen)}
            end)

          init_args = Enum.map(args, &elem(&1, 0))

          Enum.reduce(args, generation_leaf(init_args), &generation_clause/2)
        end

        defmacrop do_generation, do: generation_bound()

        @doc false
        @spec __generator__() :: StreamData.t(%__MODULE__{})
        def __generator__, do: __generator__(%__MODULE__{})

        @spec __generator__(%__MODULE__{}) :: StreamData.t()
        def __generator__(%__MODULE__{} = this) do
          do_generation()
          |> StreamData.map(&Tuple.to_list/1)
          |> StreamData.map(&Enum.zip(@__generator__.fields, &1))
          |> StreamData.map(&struct(this, &1))
        end

        defoverridable __generator__: 1
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

    field = Map.get(config, :collectable, false)
    if field && field not in fields, do: raise(KeyError, key: field, term: __MODULE__)
    collectable_ast = collectable_ast(field)

    # [MAYBE] fields |> Enum.zip(Stream.cycle([StreamData.term()])) |> Keyword.merge(types),
    types =
      with {:module, _} <- Code.ensure_compiled(StreamData),
           types when is_list(types) <- Map.get(config, :generator, false),
           true <- Keyword.keyword?(types),
           do: types,
           else: (_ -> false)

    enumerable_ast = enumerable_ast(Map.get(config, :enumerable, false), fields)

    generator_ast = generator_ast(types)

    [access_ast, enumerable_ast, collectable_ast, generator_ast]
    |> Enum.map(&List.wrap/1)
    |> Enum.reduce(&Kernel.++/2)
  end
end
