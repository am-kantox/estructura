defmodule Estructura.WIA do
  @moduledoc ~S"""
  `Estructura.WIA` (With Indifferent Access) provides a struct-like container
    that can be accessed by both atom and binary keys, replicating
    Ruby’s `Hash#with_indifferent_access` pattern.

  Internally, keys are always stored as atoms. Both atom and binary keys
    are accepted in `Access` operations and normalized to atoms transparently.

  ## Usage

  ```elixir
  defmodule MyWIA do
    use Estructura.WIA,
      fields: [
        foo: [default: 42],
        bar: [default: ""],
        baz: [default: %{}]
      ]

    @impl MyWIA.Coercible
    def coerce_foo(value) when is_integer(value), do: {:ok, value}
    def coerce_foo(value) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "not a valid integer"}
      end
    end

    @impl MyWIA.Validatable
    def validate_foo(value) when value >= 0, do: {:ok, value}
    def validate_foo(_), do: {:error, ":foo must be non-negative"}
  end
  ```

  Then both atom and binary keys work interchangeably:

  ```elixir
  wia = %MyWIA{}
  wia[:foo]        #=> 42
  wia["foo"]       #=> 42
  put_in(wia, ["foo"], 100)  #=> %MyWIA{foo: 100, ...}
  ```

  ## Options

  * `fields` — a keyword list of `{field_name, opts}` where `opts` is a keyword list with:
    * `:default` — the default value for the field (default: `nil`)
    * `:coerce` — whether to generate a coercion callback for this field (default: `false`)
    * `:validate` — whether to generate a validation callback for this field (default: `false`)

  ## Protocols

  `Inspect`, `Enumerable`, and `Collectable` protocols are automatically
    implemented to mimic plain map behaviour.
  If `Jason` is compiled and available, `Jason.Encoder` is also derived.
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      @__wia_opts__ unquote(opts)
      @before_compile Estructura.WIA
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :__wia_opts__)
    field_specs = Keyword.get(opts, :fields, [])

    unless Keyword.keyword?(field_specs) do
      raise CompileError,
        description:
          "`use Estructura.WIA` expects `fields` to be a keyword list, got: #{inspect(field_specs)}"
    end

    field_names = Keyword.keys(field_specs)

    defaults =
      Enum.map(field_specs, fn {name, spec} ->
        {name, Keyword.get(spec, :default, nil)}
      end)

    coerced_fields =
      for {name, spec} <- field_specs,
          Keyword.get(spec, :coerce, false),
          do: name

    validated_fields =
      for {name, spec} <- field_specs,
          Keyword.get(spec, :validate, false),
          do: name

    atom_to_string_map =
      Map.new(field_names, fn name -> {name, Atom.to_string(name)} end)

    string_to_atom_map =
      Map.new(field_names, fn name -> {Atom.to_string(name), name} end)

    access_ast = wia_access_ast(field_names)
    coercion_ast = wia_coercion_ast(coerced_fields, env.module, field_names)
    validation_ast = wia_validation_ast(validated_fields, env.module, field_names)
    protocol_ast = wia_protocol_ast(field_names)
    jason_ast = wia_jason_ast(field_names)

    defstruct_ast =
      quote generated: true, location: :keep do
        defstruct unquote(Macro.escape(defaults))
      end

    key_helpers_ast =
      quote generated: true, location: :keep do
        @__wia_fields__ unquote(field_names)
        @__wia_atom_to_string__ unquote(Macro.escape(atom_to_string_map))
        @__wia_string_to_atom__ unquote(Macro.escape(string_to_atom_map))

        @doc false
        @spec __fields__() :: [atom()]
        def __fields__, do: @__wia_fields__

        @doc false
        @compile {:inline, normalize_key: 1}
        def normalize_key(key) when is_atom(key) and is_map_key(@__wia_atom_to_string__, key),
          do: {:ok, key}

        def normalize_key(key) when is_binary(key) and is_map_key(@__wia_string_to_atom__, key),
          do: {:ok, @__wia_string_to_atom__[key]}

        def normalize_key(_key), do: :error
      end

    [defstruct_ast, key_helpers_ast, coercion_ast, validation_ast, access_ast | protocol_ast] ++
      List.wrap(jason_ast)
  end

  #############################################################################
  ## Access implementation
  #############################################################################

  @doc false
  @spec wia_access_ast([atom()]) :: Macro.t()
  defp wia_access_ast(fields) do
    put_clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          def put(%__MODULE__{} = data, unquote(key), value) do
            with {:coercion, {:ok, value}} <- {:coercion, coerce_value(unquote(key), value)},
                 {:validation, {:ok, value}} <- {:validation, validate_value(unquote(key), value)} do
              {:ok, %{data | unquote(key) => value}}
            else
              {reason, {:error, error}} -> {:error, {reason, error}}
            end
          end
        end
      end

    quote generated: true, location: :keep do
      @behaviour Access

      @doc """
      Puts the value for the given key, passing coercion and validation.

      Returns `{:ok, updated_struct}` or `{:error, {reason, details}}`.
      The key can be an atom or a binary string.
      """
      @spec put(%__MODULE__{}, atom() | binary(), any()) ::
              {:ok, %__MODULE__{}} | {:error, any()}
      def put(data, key, value)

      @doc """
      Puts the value for the given key, passing coercion and validation.

      Returns the updated struct or raises on failure.
      The key can be an atom or a binary string.
      """
      @spec put!(%__MODULE__{}, atom() | binary(), any()) :: %__MODULE__{} | no_return()
      def put!(data, key, value)

      @doc """
      Gets the value for the given key.

      The key can be an atom or a binary string.
      """
      @spec get(%__MODULE__{}, atom() | binary(), any()) :: any()
      def get(data, key, default \\ nil)

      # Indifferent wrappers: normalize, then dispatch to atom-keyed clauses

      def put(%__MODULE__{} = data, key, value) when is_binary(key) do
        case normalize_key(key) do
          {:ok, atom_key} -> put(data, atom_key, value)
          :error -> {:error, Exception.message(%KeyError{key: key, term: data})}
        end
      end

      unquote_splicing(put_clauses)

      def put(%__MODULE__{} = term, key, _value),
        do: {:error, Exception.message(%KeyError{key: key, term: term})}

      def put!(%__MODULE__{} = data, key, value) do
        case put(data, key, value) do
          {:ok, updated} ->
            updated

          {:error, {type, reason}} ->
            raise Estructura.Error,
              estructura: __MODULE__,
              type: type,
              key: key,
              value: value,
              reason: reason

          {:error, message} when is_binary(message) ->
            raise KeyError, key: key, term: data
        end
      end

      def get(%__MODULE__{} = data, key, default) when is_binary(key) do
        case normalize_key(key) do
          {:ok, atom_key} -> get(data, atom_key, default)
          :error -> default
        end
      end

      def get(%__MODULE__{} = data, key, default) when is_atom(key) do
        case Map.fetch(data, key) do
          {:ok, value} -> value
          :error -> default
        end
      end

      def get(%__MODULE__{}, _key, default), do: default

      @impl Access
      def fetch(%__MODULE__{} = data, key) do
        with {:ok, atom_key} <- normalize_key(key),
             %{^atom_key => value} <- data,
             do: {:ok, value},
             else: (_ -> :error)
      end

      @impl Access
      def pop(%__MODULE__{} = data, key) do
        with {:ok, atom_key} <- normalize_key(key),
             %{^atom_key => value} <- data,
             do: {value, %{data | atom_key => nil}},
             else: (_ -> {nil, data})
      end

      @impl Access
      def get_and_update(%__MODULE__{} = data, key, fun) do
        case normalize_key(key) do
          {:ok, atom_key} ->
            current = Map.get(data, atom_key)

            case fun.(current) do
              :pop ->
                pop(data, atom_key)

              {current_value, new_value} ->
                {current_value, put!(data, atom_key, new_value)}
            end

          :error ->
            raise KeyError, key: key, term: data
        end
      end
    end
  end

  #############################################################################
  ## Coercion
  #############################################################################

  @doc false
  @spec wia_coercion_ast([atom()], module(), [atom()]) :: Macro.t()
  defp wia_coercion_ast([], _module, all_fields) do
    quote generated: true, location: :keep do
      @compile {:inline, coerce_value: 2}
      defp coerce_value(key, value) when key in unquote(all_fields), do: {:ok, value}
    end
  end

  defp wia_coercion_ast(fields, module, all_fields) do
    coercible = Module.concat(module, Coercible)

    doc =
      quote do
        @moduledoc false
        """
        Coercion behaviour for `#{inspect(unquote(module))}`.
        Implement `coerce_<field>/1` callbacks for coerced fields.
        """
      end

    callbacks =
      for key <- fields do
        quote generated: true, location: :keep do
          @doc """
          Coercion function for the `#{unquote(key)}` field.
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
          defp coerce_value(unquote(key), value),
            do: apply(__MODULE__, unquote(:"coerce_#{key}"), [value])
        end
      end

    remaining = all_fields -- fields

    passthrough =
      if remaining != [] do
        quote generated: true, location: :keep do
          defp coerce_value(key, value) when key in unquote(remaining), do: {:ok, value}
        end
      end

    List.flatten([behaviour_clause, coerce_clauses, List.wrap(passthrough)])
  end

  #############################################################################
  ## Validation
  #############################################################################

  @doc false
  @spec wia_validation_ast([atom()], module(), [atom()]) :: Macro.t()
  defp wia_validation_ast([], _module, all_fields) do
    quote generated: true, location: :keep do
      defp validate_value(key, value) when key in unquote(all_fields), do: {:ok, value}
    end
  end

  defp wia_validation_ast(fields, module, all_fields) do
    validatable = Module.concat(module, Validatable)

    doc =
      quote do
        @moduledoc false
        """
        Validation behaviour for `#{inspect(unquote(module))}`.
        Implement `validate_<field>/1` callbacks for validated fields.
        """
      end

    callbacks =
      for key <- fields do
        quote generated: true, location: :keep do
          @doc """
          Validation function for the `#{unquote(key)}` field.
          """
          @callback unquote(:"validate_#{key}")(value) :: {:ok, value} | {:error, value}
                    when value: any()
        end
      end

    Module.create(validatable, [doc | callbacks], __ENV__)

    behaviour_clause = quote(do: @behaviour(unquote(validatable)))

    validate_clauses =
      for key <- fields do
        quote generated: true, location: :keep do
          defp validate_value(unquote(key), value),
            do: apply(__MODULE__, unquote(:"validate_#{key}"), [value])
        end
      end

    remaining = all_fields -- fields

    passthrough =
      if remaining != [] do
        quote generated: true, location: :keep do
          defp validate_value(key, value) when key in unquote(remaining), do: {:ok, value}
        end
      end

    List.flatten([behaviour_clause, validate_clauses, List.wrap(passthrough)])
  end

  #############################################################################
  ## Protocols: Inspect, Enumerable, Collectable
  #############################################################################

  @doc false
  @spec wia_protocol_ast([atom()]) :: [Macro.t()]
  defp wia_protocol_ast(fields) do
    count = length(fields)

    [
      quote generated: true, location: :keep, bind_quoted: [fields: fields, count: count] do
        module = __MODULE__

        defimpl Inspect do
          @moduledoc false
          import Inspect.Algebra

          def inspect(%unquote(module){} = wia, opts) do
            fields = unquote(fields)

            map_contents =
              for key <- fields do
                key_doc = Inspect.Algebra.color("#{key}:", :atom, opts)
                concat(key_doc, concat(" ", to_doc(Map.get(wia, key), opts)))
              end

            container_doc(
              "%#{Kernel.inspect(unquote(module))}{",
              map_contents,
              "}",
              opts,
              fn doc, _opts -> doc end
            )
          end
        end

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

        defimpl Collectable do
          @moduledoc false

          def into(%unquote(module){} = wia) do
            fun = fn
              list, {:cont, {key, value}} ->
                case unquote(module).normalize_key(key) do
                  {:ok, atom_key} -> [{atom_key, value} | list]
                  :error -> raise KeyError, key: key, term: wia
                end

              list, :done ->
                Enum.reduce(list, wia, fn {key, value}, s ->
                  unquote(module).put!(s, key, value)
                end)

              _list, :halt ->
                :ok
            end

            {[], fun}
          end
        end
      end
    ]
  end

  #############################################################################
  ## Jason
  #############################################################################

  @doc false
  @spec wia_jason_ast([atom()]) :: Macro.t() | nil
  defp wia_jason_ast(fields) do
    if Code.ensure_compiled(Jason) == {:module, Jason} do
      quote generated: true, location: :keep, bind_quoted: [fields: fields] do
        module = __MODULE__

        defimpl Jason.Encoder do
          @moduledoc false

          def encode(%unquote(module){} = wia, opts) do
            map =
              for key <- unquote(fields), into: %{} do
                {key, Map.get(wia, key)}
              end

            Jason.Encode.map(map, opts)
          end
        end
      end
    end
  end
end
