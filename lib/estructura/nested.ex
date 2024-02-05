defmodule Estructura.Nested do
  @moduledoc """
  The nested struct with helpers to easily describe it and produce
    validation, coercion, and generation helpers.
  """

  @actions ~w|coerce validate generate|a

  @typep action :: :coerce | :validate | :generate
  @typep functions :: [{:coerce, atom()} | {:validate, atom()} | {:generate, atom()}]
  @typep definitions :: %{defs: Macro.input(), funs: functions()}
  @typep mfargs :: {module(), atom(), list()}
  @typep simple_type_variants :: atom() | {atom(), any()} | mfargs()
  @typep simple_type :: {:simple, simple_type_variants()}
  @typep estructura_type :: {:estructura, module()}
  @typep shape :: %{required(atom()) => simple_type() | estructura_type()}

  @doc false
  defmacro __using__(opts \\ []) do
    quote generated: true, location: :keep, bind_quoted: [opts: opts] do
      import Estructura.Nested

      Module.register_attribute(__MODULE__, :__estructura_nested__,
        accumulate: false,
        persist: true
      )

      Module.put_attribute(__MODULE__, :__estructura_nested__, Map.new(opts))
      @before_compile Estructura.Nested
    end
  end

  @doc """
  Declares the shape of the target nested map. the values might be:

  - `:string` | `:integer` or another simple `type` understood by
    [`StreamData`](https://hexdocs.pm/stream_data/StreamData.html#functions)
  - `[type]` to declare a list of elements of a single `type`
  - `map` to declare a nesting level; in such a case, the module with the FQN
    is created, carrying the struct of the same behaviour
  - `mfa` tuple pointing out to the generator for this value

  ## Example

  ```elixir
  defmodule User do
    use Estructura.Nested
    shape %{
      name: :string,
      address: %{city: :string, street: %{name: [:string], house: :string}},
      data: %{age: :float}
    }
  end

  %User{}
  ```

  would result in

  ```elixir
  %User{
    address: %User.Address{
      city: nil,
      street: %User.Address.Street{house: nil, name: []}
    },
    data: %User.Data{age: nil},
    name: nil
    }
  ```

  """
  defmacro shape(opts) do
    quote generated: true, location: :keep, bind_quoted: [opts: opts] do
      nested = Module.get_attribute(__MODULE__, :__estructura_nested__)
      Module.put_attribute(__MODULE__, :__estructura_nested__, Map.put(nested, :shape, opts))
    end
  end

  Enum.each(@actions -- [:generate], fn name ->
    doc =
      """
      DSL helper to produce **`#{name}`** callbacks. The syntax is kinda weird,
        but bear with it, please.

      It’s known to produce warnings in `credo`, I’m working on it.
      """ <>
        case name do
          :coerce ->
            """
            ```elixir
            coerce do
              def data.age(age) when is_float(age), do: {:ok, age}
              def data.age(age) when is_integer(age), do: {:ok, 1.0 * age}
              def data.age(age) when is_binary(age), do: {:ok, String.to_float(age)}
              def data.age(age), do: {:error, "Could not cast \#{inspect(age)} to float"}
            end
            ```
            """

          :validate ->
            """
            ```elixir
            validate do
              def address.street.postal_code(<<?0, code::binary-size(4)>>),
                do: {:ok, code}
              def address.street.postal_code(code),
                do: {:error, "Not a postal code (\#{inspect(code)})"}
            end
            ```
            """
        end

    @doc doc
    defmacro unquote(name)(opts) do
      name = unquote(name)
      opts = Macro.escape(opts)

      quote generated: true, location: :keep do
        opts =
          unquote(opts)
          |> Estructura.Nested.normalize()
          |> Estructura.Nested.reshape(unquote(name), __MODULE__)

        nested = Module.get_attribute(__MODULE__, :__estructura_nested__)

        Module.put_attribute(
          __MODULE__,
          :__estructura_nested__,
          Map.update(nested, unquote(name), opts, &(&1 ++ opts))
        )
      end
    end
  end)

  @doc false
  defmacro __before_compile__(env) do
    {shape, nested} =
      env.module |> Module.get_attribute(:__estructura_nested__) |> Map.pop!(:shape)

    impls =
      for {action, defs} when action in unquote(@actions) <- nested,
          {{module, fun}, def} <- defs,
          reduce: %{} do
        acc ->
          acc
          |> Map.put_new(module, %{funs: [], defs: []})
          |> update_in([module, :defs], &(&1 ++ [def]))
          |> update_in([module, :funs], &(&1 ++ [fun]))
      end

    slice(env.module, nil, shape, impls)
  end

  @doc false
  @spec from_term(module(), map() | [map()], keyword()) ::
          {:ok, struct()} | {:error, Exception.t()}
  def from_term(module, map, options \\ [])

  def from_term(module, list, options) when is_list(list),
    do: Enum.map(list, &from_term(module, &1, options))

  def from_term(module, %{} = map, options) do
    {result, [], errors} = do_from_map({struct!(module, []), [], []}, map, options)

    case errors do
      [] -> {:ok, result}
      errors -> {:error, squeeze(errors, %KeyError{key: [], term: module})}
    end
  end

  defp atomize(key) when is_list(key), do: Enum.map(key, &atomize/1)
  defp atomize(key) when is_atom(key), do: key
  defp atomize(key) when is_binary(key), do: String.to_existing_atom(key)

  defp squeeze([], acc), do: acc

  defp squeeze(
         [%KeyError{key: key, term: term, message: msg} | rest],
         %KeyError{key: keys, term: parent, message: message} = acc
       ) do
    path = [term, parent] |> Enum.map(&Module.split/1) |> trim_left()
    key = path |> Kernel.++([key]) |> Enum.join(".") |> String.downcase()

    squeeze(rest, %KeyError{
      acc
      | key: [key | keys],
        message: [msg, message] |> Enum.filter(&is_binary/1) |> Enum.join("\n")
    })
  end

  defp trim_left([list, []]), do: list
  defp trim_left([[h | list], [h | lead]]), do: trim_left([list, lead])

  @spec do_from_map({struct(), [atom()], [Exception.t()]}, map(), keyword()) ::
          {struct(), [atom()], [Exception.t()]}
  defp do_from_map(acc, map, options) do
    Enum.reduce(map, acc, fn
      {key, %{} = map}, {into, path, errors} when not is_struct(map) ->
        {into, [_ | path], errors} =
          do_from_map({into, [atomize(key) | path], errors}, map, options)

        {into, path, errors}

      {key, value}, {into, path, errors} ->
        key = to_string(key)

        {delim, num} =
          case Keyword.get(options, :split, false) do
            false -> {"_", 1}
            true -> {"_", -1}
            num when is_integer(num) and num > 1 -> {"_", num}
            delim when is_binary(delim) -> {delim, -1}
            {delim, num} when is_binary(delim) and is_integer(num) and num > 1 -> {delim, num}
          end

        num = if num < 1, do: Enum.count(String.split(key, delim)), else: num
        key_paths = Enum.map(1..num//1, &String.split(key, "_", parts: &1))

        Enum.reduce_while(key_paths, {false, into}, fn key_path, {false, into} ->
          try do
            key_path = Enum.reverse(path) ++ atomize(key_path)
            {:halt, {true, put_in(into, key_path, value)}}
          rescue
            _e in [ArgumentError, KeyError] -> {:cont, {false, into}}
          end
        end)
        |> case do
          {true, into} ->
            {into, path, errors}

          {false, into} ->
            key = [key | path] |> Enum.reverse() |> Enum.join(".")

            {into, path,
             [
               %KeyError{
                 message: "Unknown key in nested struct: ‹#{key}›",
                 key: key,
                 term: into.__struct__
               }
               | errors
             ]}
        end
    end)
  end

  @doc false
  @spec normalize(Macro.input()) :: Macro.input()
  def normalize(do: block), do: normalize(block)
  def normalize({:__block__, [], clauses}), do: clauses
  def normalize(clauses), do: List.wrap(clauses)

  @doc false
  @spec reshape(Macro.input(), action(), module()) ::
          {module(), {action(), atom()}, Macro.output()}
          | [{module(), {action(), atom()}, Macro.output()}]
  def reshape(defs, action, module) when is_list(defs),
    do: Enum.map(defs, &reshape(&1, action, module))

  def reshape(
        {:def, meta, [{:when, when_meta, [{def, submeta, args}, guard]} | rest]},
        action,
        module
      ) do
    {acc, def} = expand_def(module, def)

    {{acc, {action, def}},
     [
       {:@, meta, [{:impl, [], [true]}]},
       {:def, meta, [{:when, when_meta, [{:"#{action}_#{def}", submeta, args}, guard]} | rest]}
     ]}
  end

  def reshape({:def, meta, [{def, submeta, args} | rest]}, action, module) do
    {acc, def} = expand_def(module, def)

    {{acc, {action, def}},
     [
       {:@, meta, [{:impl, [], [true]}]},
       {:def, meta, [{:"#{action}_#{def}", submeta, args} | rest]}
     ]}
  end

  def reshape({:defdelegate, meta, [{def, submeta, args}, [to: destination]]}, action, module) do
    destination =
      case destination do
        nickname when is_atom(nickname) ->
          Module.concat(Estructura.Coercers, nickname |> Atom.to_string() |> Macro.camelize())

        other ->
          other
      end

    {acc, def} = expand_def(module, def)
    wrapped_call = [[do: {{:., submeta, [destination, action]}, submeta, args}]]

    {{acc, {action, def}},
     [
       {:@, meta, [{:impl, [], [true]}]},
       {:def, meta, [{:"#{action}_#{def}", submeta, args} | wrapped_call]}
     ]}
  end

  @spec slice(module(), atom(), map(), %{required(module()) => definitions()}) ::
          Macro.output() | {atom(), {:estructura, module()}}
  defp slice(module, name, %{} = fields, impls) do
    impl = Map.get(impls, module, %{funs: [], defs: []})

    complex =
      for {name, %{} = subslice} <- fields, into: %{} do
        module
        |> Module.concat(name |> to_string() |> Macro.camelize())
        |> slice(name, subslice, impls)
      end

    all =
      fields
      |> Enum.reduce(%{}, fn
        {_, %{}}, acc -> acc
        {name, [type]}, acc -> Map.put(acc, name, {:list, type})
        {name, [_ | _] = types}, acc -> Map.put(acc, name, {:mixed, types})
        {name, type}, acc -> Map.put(acc, name, {:simple, type})
      end)
      |> Map.merge(complex)

    if is_nil(name) do
      module_ast(module, false, all, impl)
    else
      Module.create(module, module_ast(module, true, all, impl), __ENV__)
      {name, {:estructura, module}}
    end
  end

  @spec coercions_and_validations(functions()) :: {[atom()], [atom()]}
  defp coercions_and_validations(funs) do
    {
      for({:coerce, fun} <- funs, uniq: true, do: fun),
      for({:validate, fun} <- funs, uniq: true, do: fun)
    }
  end

  @spec struct_ast(shape()) :: [{atom(), nil | struct()}]
  defp struct_ast(fields) do
    Enum.map(fields, fn
      {name, {:list, _type}} -> {name, []}
      {name, {:mixed, _types}} -> {name, []}
      {name, {:simple, _type}} -> {name, nil}
      {name, {:estructura, module}} -> {name, struct!(module, [])}
    end)
  end

  @spec generator_ast(shape()) :: [{atom(), mfargs()}]
  defp generator_ast(fields) do
    Enum.map(fields, fn
      {name, {:list, type}} -> {name, stream_data_type_for([type])}
      {name, {:mixed, types}} -> {name, stream_data_type_for(types)}
      {name, {:simple, type}} -> {name, stream_data_type_for(type)}
      {name, {:estructura, module}} -> {name, {module, :__generator__, []}}
    end)
  end

  @spec stream_data_type_for(simple_type_variants() | [simple_type_variants()]) :: mfargs()
  defp stream_data_type_for({:datetime, opts}),
    do: {Estructura.StreamData, :datetime, [opts]}

  defp stream_data_type_for(:datetime),
    do: stream_data_type_for({:datetime, []})

  defp stream_data_type_for({:date, opts}),
    do: {Estructura.StreamData, :date, [opts]}

  defp stream_data_type_for(:date),
    do: stream_data_type_for({:date, []})

  defp stream_data_type_for({:constant, const}),
    do: {StreamData, :constant, [const]}

  defp stream_data_type_for({:string, kind}),
    do: {StreamData, :string, [kind]}

  defp stream_data_type_for(:string),
    do: stream_data_type_for({:string, :alphanumeric})

  defp stream_data_type_for([type]) do
    stream_data_type_for({StreamData, :list_of, [stream_data_type_for(type)]})
  end

  defp stream_data_type_for(type) when is_atom(type),
    do: {StreamData, type, []}

  defp stream_data_type_for({_, _, _} = type),
    do: type

  defp stream_data_type_for(const),
    do: {StreamData, :constant, [const]}

  @spec module_ast(module(), boolean(), shape(), definitions()) :: Macro.output()
  defp module_ast(module, nested?, fields, %{funs: funs, defs: defs}) do
    {coercions, validations} = coercions_and_validations(funs)
    struct = struct_ast(fields)
    generator = generator_ast(fields)

    [
      quote do
        if unquote(nested?), do: @moduledoc(false)

        if {:module, Jason} == Code.ensure_compiled(Jason) do
          @derive Jason.Encoder

          @doc "Safely parses the json, applying all the specified validations and coercions"
          @spec parse(binary()) :: {:ok, struct()} | {:error, Exception.t()}
          def parse(input) do
            with {:ok, decoded} <- Jason.decode(input),
                 do: unquote(module).cast(decoded)
          end

          @doc "Same as `parse/1` but either returns the result of successful parsing or raises"
          @spec parse!(binary()) :: struct() | no_return()
          def parse!(input),
            do: input |> Jason.decode!() |> unquote(module).cast!()
        end

        @derive Estructura.Transformer
        @derive Estructura.Flattenable

        defstruct unquote(Macro.escape(struct))

        @doc """
        Casts the map representation as given to `Estructura.Nested.shape/1` to
          the nested `Estructura` instance.

        If `split: true` is passed as an option, it will attempt to put `foo_bar` into nested `%{foo: %{bar: _}}`
        """
        def cast(%{} = content, options \\ []),
          do: Estructura.Nested.from_term(unquote(module), content, options)

        def cast!(%{} = content, options \\ []) do
          content
          |> cast(options)
          |> case do
            {:ok, cast} -> cast
            {:error, error} -> raise error
          end
        end

        unquote(defs)
      end
      | Estructura.Hooks.estructura_ast(
          module,
          struct!(Estructura.Config,
            access: true,
            coercion: coercions,
            validation: validations,
            generator: generator
          ),
          Map.keys(fields)
        )
    ]
  end

  @doc false
  @spec expand_def(module(), Macro.input()) :: {module(), Macro.output()}
  defp expand_def(module, def) do
    {def, acc} =
      Macro.postwalk(def, [], fn
        {:., _meta, [{prefix, _, _}, suffix]}, acc -> {suffix, [prefix | acc]}
        e, acc -> {e, acc}
      end)

    module =
      [module | Enum.reverse(acc)]
      |> Enum.map(&to_string/1)
      |> Enum.map(&Macro.camelize/1)
      |> Module.concat()

    {module, def}
  end
end
