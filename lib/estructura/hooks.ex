defmodule Estructura.Hooks do
  @moduledoc false

  alias Estructura.Config, as: Cfg

  @spec access_ast(boolean(), [{Cfg.key(), binary()}], [Cfg.key()]) :: Macro.t()
  defp access_ast(false, _calculated, _fields), do: []

  defp access_ast(lazy?, calculated, fields) when lazy? in [true, :lazy] and is_list(fields) do
    opening =
      quote generated: true, location: :keep do
        alias Estructura.Lazy

        @behaviour Access

        @estructura_calculated_fields Module.get_attribute(
                                        __MODULE__,
                                        :calculated,
                                        unquote(calculated)
                                        |> Enum.map(fn
                                          {k, %{__struct__: Formulae} = formula} ->
                                            {k, formula}

                                          {k, formula} when is_binary(formula) ->
                                            {
                                              k,
                                              # credo:disable-for-next-line
                                              apply(Formulae, :compile, [
                                                formula,
                                                [imports: :none]
                                              ])
                                            }

                                          {k, formula} when is_function(formula, 1) ->
                                            {k, formula}
                                        end)
                                      )

        @doc """
        Puts the value for the given key into the structure, passing coercion _and_ validation,
          returns `{:ok, updated_struct}` or `{:error, reason}` if there is no such key
        """
        @spec put(%__MODULE__{}, Cfg.key(), any()) :: {:ok, %__MODULE__{}} | {:error, any}
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

    recalculate_clause =
      quote generated: true, location: :keep do
        def recalculate_calculated(%__MODULE__{} = data) do
          Estructura.recalculate_calculated(data, @estructura_calculated_fields)
        end
      end

    clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          def put(%__MODULE__{unquote(key) => _} = data, unquote(key), value) do
            # [AM] maybe do that instead?
            # with {:ok, value} <- coerce_value(unquote(key), value),
            #      {:ok, value} <- validate_value(unquote(key), value) do
            #   {:ok, recalculate_calculated(%__MODULE__{data | unquote(key) => value})}
            # end

            with {:coercion, {:ok, value}} <- {:coercion, coerce_value(unquote(key), value)},
                 {:validation, {:ok, value}} <- {:validation, validate_value(unquote(key), value)} do
              {:ok, recalculate_calculated(%__MODULE__{data | unquote(key) => value})}
            else
              {reason, {:error, error}} -> {:error, {reason, error}}
            end
          end

          def put!(%__MODULE__{unquote(key) => _} = data, unquote(key), value) do
            case put(data, unquote(key), value) do
              {:ok, updated_data} ->
                updated_data

              {:error, {type, reason}} ->
                raise Estructura.Error,
                  estructura: __MODULE__,
                  type: type,
                  key: unquote(key),
                  value: value,
                  reason: reason
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
        def put(%__MODULE__{} = term, key, _),
          do: {:error, Exception.message(%KeyError{key: key, term: term})}

        def put!(%__MODULE__{} = term, key, _),
          do: raise(KeyError, key: key, term: term)

        def get(%__MODULE__{}, _key, default),
          do: default

        @impl Access
        def fetch(%__MODULE__{}, _key), do: :error

        @impl Access
        def pop(%__MODULE__{} = data, _key), do: {nil, data}

        @impl Access
        def get_and_update(%__MODULE__{} = term, key, _),
          do: raise(KeyError, key: key, term: term)
      end

    [opening, recalculate_clause | clauses] ++ [closing]
  end

  @spec coercion_ast(boolean() | [Cfg.key()], module(), [Cfg.key()]) :: Macro.t()
  defp coercion_ast(false, _, all_fields),
    do: [
      quote do
        @compile {:inline, coerce_value: 2}
        defp coerce_value(key, value) when key in unquote(all_fields), do: {:ok, value}
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

    # shape =
    #   with true <- Module.open?(module),
    #        %{} = nested <- Module.get_attribute(module, :__estructura_nested__),
    #        do: Map.get(nested, :shape),
    #        else: (_ -> %{})

    # IO.inspect(
    #   fields: fields,
    #   all_fields: all_fields,
    #   shape: shape
    # )

    Module.create(coercible, [doc | callbacks], __ENV__)

    behaviour_clause = quote(do: @behaviour(unquote(coercible)))

    coerce_clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          defp coerce_value(unquote(key), value),
            do: apply(__MODULE__, unquote(:"coerce_#{key}"), [value])
        end
      end

    [behaviour_clause | coerce_clauses] ++ coercion_ast(false, module, all_fields)
  end

  @spec validation_ast(boolean() | [Cfg.key()], module(), [Cfg.key()]) :: Macro.t()
  defp validation_ast(false, _, all_fields),
    do: [
      quote do
        defp validate_value(key, value) when key in unquote(all_fields), do: {:ok, value}
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
          defp validate_value(unquote(key), value),
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
        @moduledoc false
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
        @moduledoc false
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

      {usage, declarations} =
        cond do
          Module.has_attribute?(__MODULE__, :__estructura__) ->
            {"`use Estructura`",
             [
               shape:
                 inspect(Module.get_attribute(__MODULE__, :__estructura__),
                   pretty: true,
                   width: 80
                 )
             ]}

          Module.has_attribute?(__MODULE__, :__estructura_nested__) ->
            estructura = Module.get_attribute(__MODULE__, :__estructura_nested__)
            matcher = ~r/\n([[:space:]]*def.*end)\n]/usm

            result =
              [:coerce, :validate]
              |> Enum.map(fn what ->
                {what,
                 estructura
                 |> Map.get(what, [])
                 |> Enum.flat_map(fn {_who, ast} ->
                   matcher
                   |> Regex.scan(Macro.to_string(ast), capture: :all_but_first)
                   |> case do
                     [list] when is_list(list) -> list
                     _ -> []
                   end
                 end)
                 |> Enum.join("\n")}
              end)
              |> Keyword.put(:shape, inspect(estructura.shape, pretty: true, width: 80))

            {"`use Estructura.Nested`", result}

          true ->
            {"N/A", []}
        end

      declarations =
        declarations
        |> Enum.reject(&match?({_, ""}, &1))
        |> Enum.map_join("\n", fn {key, declaration} ->
          "\n## #{key}\n```elixir\n#{declaration}\n```\n"
        end)

      @doc "See `#{inspect(__MODULE__)}.__generator__/1`"
      @spec __generator__() :: StreamData.t(%__MODULE__{})
      def __generator__, do: __generator__(%__MODULE__{})

      @doc ~s"""
      Returns the generator to be used in `StreamData`-powered property testing, based
        on the specification given to #{usage}, which contained

      #{declarations}

      The argument given would be used as a template to generate new values.
      """
      @spec __generator__(%__MODULE__{}) :: StreamData.t(%__MODULE__{})
      def __generator__(%__MODULE__{} = this) do
        producer =
          if {:cast, 1} in __MODULE__.__info__(:functions) do
            fn content ->
              # credo:disable-for-next-line
              case apply(__MODULE__, :cast, [content]) do
                {:ok, %__MODULE__{} = instance} -> instance
                _ -> nil
              end
            end
          else
            &struct!(this, &1)
          end

        do_generation()
        |> StreamData.map(&Tuple.to_list/1)
        |> StreamData.map(&Enum.zip(unquote(fields), &1))
        |> StreamData.map(producer)
        |> StreamData.filter(&(not is_nil(&1)))
        |> StreamData.map(&recalculate_calculated/1)
      end

      defoverridable __generator__: 1
    end
  end

  ##############################################################################

  @spec fields(module()) :: [Cfg.key()]
  if Version.compare(System.version(), "1.18.0-rc.0") == :lt do
    defp fields(module) do
      module
      |> Macro.struct!(__ENV__)
      |> Map.delete(:__struct__)
      |> Map.keys()
    end
  else
    defp fields(module) do
      module |> Macro.struct_info!(__ENV__) |> Enum.map(& &1.field)
    rescue
      _ in [Estructura.Error] -> []
    end
  end

  defmacro inject_estructura(env) do
    config = Module.get_attribute(env.module, :__estructura__)
    estructura_ast(env.module, config, fields(env.module))
  end

  @doc false
  def estructura_ast(module, config, fields) do
    fields =
      case config.access do
        :lazy ->
          if :__lazy_data__ in fields do
            fields -- [:__lazy_data__]
          else
            raise CompileError,
              description:
                "`:__lazy_data__` struct key must be defined for `access: :lazy` config"
          end

        false ->
          cond do
            {config.coercion, config.validation} != {false, false} ->
              raise CompileError,
                description: "`access: true` is required to use coercion and/or validation"

            config.calculated != [] ->
              raise CompileError,
                description: "`access: true` is required to use calculated fields"

            true ->
              fields
          end

        true ->
          fields
      end

    access_ast = access_ast(config.access, config.calculated, fields)
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
