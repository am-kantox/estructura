defmodule Estructura.Hooks do
  @moduledoc false

  alias Estructura.Config, as: Cfg

  @spec access_ast(boolean(), [Cfg.key()]) :: Macro.t()
  defp access_ast(false, _fields), do: []

  defp access_ast(lazy?, fields) when lazy? in [true, :lazy] and is_list(fields) do
    opening =
      quote generated: true, location: :keep do
        alias Estructura.Lazy

        @behaviour Access

        @doc """
        Puts the value for the given key into the structure, passing coercion _and_ validation,
          returns `{:ok, updated_struct}` or `{:error, reason}` if there is no such key
        """
        @spec put(%__MODULE__{}, Cfg.key(), any()) ::
                {:ok, %__MODULE__{}} | {:error, any}
        def put(data, key, value)

        @doc """
        Puts the value for the given key into the structure, passing coercion _and_ validation,
          returns the value or raises if there is no such key
        """
        @spec put!(%__MODULE__{}, Cfg.key(), any()) :: %__MODULE__{} | no_return
        def put!(data, key, value)

        @doc """
        Gets the value for the given key from the structure
        """
        @spec get(%__MODULE__{}, Cfg.key(), any()) :: any()
        def get(data, key, default \\ nil)
      end

    clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          def put(%__MODULE__{unquote(key) => _} = data, unquote(key), value) do
            with {:ok, value} <- coerce(unquote(key), value),
                 {:ok, value} <- validate(unquote(key), value),
                 do: {:ok, %__MODULE__{data | unquote(key) => value}}
          end

          def put!(%__MODULE__{unquote(key) => _} = data, unquote(key), value) do
            case put(data, unquote(key), value) do
              {:ok, updated_data} -> updated_data
              {:error, reason} -> raise ArgumentError, reason
            end
          end

          if unquote(lazy?) in [:lazy] do
            def get(
                  %__MODULE__{unquote(key) => %Lazy{} = value} = data,
                  unquote(key),
                  default
                ) do
              case Lazy.apply(value, data) do
                %Lazy{value: {:ok, value}} -> value
                _ -> default
              end
            end
          end

          def get(%__MODULE__{unquote(key) => value}, unquote(key), _), do: value

          if unquote(lazy?) in [:lazy] do
            @impl Access
            def fetch(
                  %__MODULE__{unquote(key) => %Lazy{} = value} = data,
                  unquote(key)
                ) do
              case Lazy.apply(value, data) do
                %Lazy{value: {:ok, value}} -> {:ok, value}
                _ -> :error
              end
            end
          end

          @impl Access
          def fetch(%__MODULE__{unquote(key) => value}, unquote(key)), do: {:ok, value}

          if unquote(lazy?) in [:lazy] do
            @impl Access
            def pop(
                  %__MODULE__{unquote(key) => %Lazy{} = value} = data,
                  unquote(key)
                ) do
              case Lazy.apply(value, data) do
                %Lazy{value: {:ok, value}} = result ->
                  {value, put!(data, unquote(key), Lazy.put(result, value))}

                _ ->
                  {nil, data}
              end
            end
          end

          @impl Access
          def pop(%__MODULE__{unquote(key) => value} = data, unquote(key)),
            do: {value, %{data | unquote(key) => nil}}

          if unquote(lazy?) in [:lazy] do
            @impl Access
            def get_and_update(
                  %__MODULE__{unquote(key) => %Lazy{} = value} = data,
                  unquote(key),
                  fun
                ) do
              case Lazy.apply(value, data) do
                %Lazy{value: {:ok, value}} = result ->
                  case fun.(value) do
                    :pop ->
                      {value, result}

                    {current_value, new_value} ->
                      {current_value, put!(data, unquote(key), Lazy.put(result, new_value))}
                  end

                _ ->
                  {nil, data}
              end
            end
          end

          @impl Access
          def get_and_update(%__MODULE__{unquote(key) => value} = data, unquote(key), fun) do
            case fun.(value) do
              :pop -> pop(data, unquote(key))
              {current_value, new_value} -> {current_value, put!(data, unquote(key), new_value)}
            end
          end
        end
      end

    closing =
      quote generated: true, location: :keep do
        def put(%__MODULE__{}, key, _),
          do: {:error, Exception.message(%KeyError{key: key, term: __MODULE__})}

        def put!(%__MODULE__{}, key, _),
          do: raise(KeyError, key: key, term: __MODULE__)

        def get(%__MODULE__{}, _key, default),
          do: default

        @impl Access
        def fetch(%__MODULE__{}, _key), do: :error

        @impl Access
        def pop(%__MODULE__{} = data, _key), do: {nil, data}

        @impl Access
        def get_and_update(%__MODULE__{}, key, _),
          do: raise(KeyError, key: key, term: __MODULE__)
      end

    [opening | clauses] ++ [closing]
  end

  @spec coercion_ast(boolean() | [Cfg.key()], module(), [Cfg.key()]) :: Macro.t()
  defp coercion_ast(false, _, all_fields),
    do: [
      quote do
        @compile {:inline, coerce: 2}
        defp coerce(key, value) when key in unquote(all_fields), do: {:ok, value}
      end
    ]

  defp coercion_ast(true, module, all_fields), do: coercion_ast(all_fields, module, all_fields)

  defp coercion_ast([], module, all_fields), do: coercion_ast(false, module, all_fields)

  defp coercion_ast(fields, module, all_fields) when is_list(fields) do
    coercible = Module.concat(module, Coercible)

    doc =
      quote do
        @moduledoc false
        """
        The behaviour for `#{inspect(unquote(module))}` specifying callbacks
          to be implemented in it for coercion of particular fields.
        """
      end

    callbacks =
      for key <- fields do
        quote generated: true, location: :keep do
          @doc """
          Coercion function to be called for `#{unquote(key)}` key
            when put through `put/3` and/or `Access`
          """
          @callback unquote(:"coerce_#{key}")(value) :: {:ok, value} | {:error, value}
                    when value: any()
        end
      end

    Module.create(coercible, [doc | callbacks], __ENV__)

    behaviour_clause = quote(do: @behaviour(unquote(coercible)))

    coerce_clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          defp coerce(unquote(key), value),
            do: apply(__MODULE__, unquote(:"coerce_#{key}"), [value])
        end
      end

    [behaviour_clause | coerce_clauses] ++ coercion_ast(false, module, all_fields)
  end

  @spec validation_ast(boolean() | [Cfg.key()], module(), [Cfg.key()]) :: Macro.t()
  defp validation_ast(false, _, all_fields),
    do: [
      quote do
        defp validate(key, value) when key in unquote(all_fields), do: {:ok, value}
      end
    ]

  defp validation_ast(true, module, all_fields),
    do: validation_ast(all_fields, module, all_fields)

  defp validation_ast([], module, all_fields), do: validation_ast(false, module, all_fields)

  defp validation_ast(fields, module, all_fields) when is_list(fields) do
    validateable = Module.concat(module, Validatable)

    doc =
      quote do
        @moduledoc false
        """
        The behaviour for `#{inspect(unquote(module))}` specifying callbacks
          to be implemented in it for validation of particular fields.
        """
      end

    callbacks =
      for key <- fields do
        quote generated: true, location: :keep do
          @doc """
          Validation function to be called for `#{unquote(key)}` key
            when put through `put/3` and/or `Access`
          """
          @callback unquote(:"validate_#{key}")(value) :: {:ok, value} | {:error, value}
                    when value: any()
        end
      end

    Module.create(validateable, [doc | callbacks], __ENV__)

    behaviour_clause = quote(do: @behaviour(unquote(validateable)))

    validate_clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          defp validate(unquote(key), value),
            do: apply(__MODULE__, unquote(:"validate_#{key}"), [value])
        end
      end

    [behaviour_clause | validate_clauses] ++ validation_ast(false, module, all_fields)
  end

  @spec enumerable_ast(boolean(), [Cfg.key()]) :: Macro.t()
  defp enumerable_ast(false, _fields), do: []

  defp enumerable_ast(true, fields) when is_list(fields) do
    count = Enum.count(fields)

    quote generated: true, location: :keep, bind_quoted: [fields: fields, count: count] do
      module = __MODULE__

      defimpl Enumerable do
        def count(_), do: {:ok, unquote(count)}

        for key <- fields do
          def member?(%unquote(module){} = s, {unquote(key), value}),
            do: {:ok, match?(%{unquote(key) => ^value}, s)}
        end

        def member?(%unquote(module){}, _), do: {:ok, false}

        if function_exported?(Enumerable.List, :slice, 4) do
          def slice(%unquote(module){} = s) do
            size = unquote(count)
            list = s |> Map.from_struct() |> :maps.to_list()

            {:ok, size, &Enumerable.List.slice(list, &1, &2, size)}
          end
        else
          def slice(%unquote(module){}), do: {:error, __MODULE__}
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

      defimpl Collectable do
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
      fields = Keyword.keys(types)

      quote generated: true, location: :keep do
        module = __MODULE__

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
        defp fix_gen(value), do: Macro.escape(value)

        # @dialyzer {:nowarn_function, generation_leaf: 1}
        defp generation_leaf(args),
          do: {{:., [], [StreamData, :constant]}, [], [{:{}, [], args}]}

        defp generation_clause({arg, gen}, acc) do
          {{:., [], [StreamData, :bind]}, [], [gen, {:fn, [], [{:->, [], [[arg], acc]}]}]}
        end

        defp generation_bound do
          args =
            Enum.map(unquote(types), fn {arg, gen} ->
              {Macro.var(arg, nil), fix_gen(gen)}
            end)

          init_args = Enum.map(args, &elem(&1, 0))

          Enum.reduce(args, generation_leaf(init_args), &generation_clause/2)
        end

        defmacrop do_generation, do: generation_bound()

        @doc "See `#{inspect(__MODULE__)}.__generator__/1`"
        @spec __generator__() :: StreamData.t(%__MODULE__{})
        def __generator__, do: __generator__(%__MODULE__{})

        @doc """
        Returns the generator to be used in `StreamData`-powered property testing, based
          on the specification given to `use #{inspect(__MODULE__)}`, which was

        ```elixir
        #{inspect(Module.get_attribute(__MODULE__, :__estructura__), pretty: true, width: 80)}
        ```

        The argument given would be used as a template to generate new values.
        """
        @spec __generator__(%__MODULE__{}) :: StreamData.t(%__MODULE__{})
        def __generator__(%__MODULE__{} = this) do
          do_generation()
          |> StreamData.map(&Tuple.to_list/1)
          |> StreamData.map(&Enum.zip(unquote(fields), &1))
          |> StreamData.map(&struct(this, &1))
        end

        defoverridable __generator__: 1
      end
    end
  end

  ##############################################################################

  @spec fields(module()) :: [Cfg.key()]
  defp fields(module) do
    module
    |> Module.get_attribute(:__struct__, %{})
    |> Map.delete(:__struct__)
    |> Map.keys()
  end

  defmacro inject_estructura(env) do
    config = Module.get_attribute(env.module, :__estructura__)
    estructura_ast(env.module, config, fields(env.module))
  end

  @doc false
  def estructura_ast(module, config, fields) do
    fields =
      if config.access == :lazy do
        if :__lazy_data__ in fields do
          fields -- [:__lazy_data__]
        else
          raise CompileError,
            description: "`:__lazy_data__` struct key must be defined for `access: :lazy` config"
        end
      else
        fields
      end

    access_ast = access_ast(config.access, fields)
    coercion_ast = coercion_ast(config.access && config.coercion, module, fields)
    validation_ast = validation_ast(config.access && config.validation, module, fields)

    field = config.collectable
    if field && field not in fields, do: raise(KeyError, key: field, term: __MODULE__)
    collectable_ast = collectable_ast(field)

    types =
      with {:module, _} <- Code.ensure_compiled(StreamData),
           types when is_list(types) <- config.generator,
           true <- Keyword.keyword?(types),
           do: Macro.escape(types),
           else: (_ -> false)

    enumerable_ast = enumerable_ast(config.enumerable, fields)

    generator_ast = generator_ast(types)

    [access_ast, coercion_ast, validation_ast, enumerable_ast, collectable_ast, generator_ast]
    |> Enum.map(&List.wrap/1)
    |> Enum.reduce(&Kernel.++/2)
  end
end
