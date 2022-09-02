defmodule Estructura.Nested do
  @moduledoc """
  The nested struct with helpers to easily describe it and produce
    validation, coercion, and generation helpers.
  """

  @actions ~w|coerce validate generate|a

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

  @doc false
  defmacro shape(opts) do
    quote generated: true, location: :keep, bind_quoted: [opts: opts] do
      nested = Module.get_attribute(__MODULE__, :__estructura_nested__)
      Module.put_attribute(__MODULE__, :__estructura_nested__, Map.put(nested, :shape, opts))
    end
  end

  Enum.each(@actions, fn name ->
    @doc false
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
          Map.put(nested, unquote(name), opts)
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
  def normalize(do: block), do: normalize(block)
  def normalize({:__block__, [], clauses}), do: clauses
  def normalize(clauses), do: List.wrap(clauses)

  @doc false
  def reshape(defs, action, module) when is_list(defs),
    do: Enum.map(defs, &reshape(&1, action, module))

  def reshape({:def, meta, [{{:., _, _} = def, submeta, args} | rest]}, action, module) do
    {acc, def} = expand_def(module, def)

    {{acc, {action, def}},
     [
       {:@, meta, [{:impl, [], [true]}]},
       {:def, meta, [{:"#{action}_#{def}", submeta, args} | rest]}
     ]}
  end

  def reshape(
        {:def, meta, [{:when, when_meta, [{{:., _, _} = def, submeta, args}, guard]} | rest]},
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
        {name, type}, acc -> Map.put(acc, name, {:simple, type})
      end)
      |> Map.merge(complex)

    if is_nil(name) do
      module_ast(module, all, impl)
    else
      Module.create(module, module_ast(module, all, impl), __ENV__)
      {name, {:estructura, module}}
    end
  end

  defp coercions_and_validations(funs) do
    {
      for({:coerce, fun} <- funs, uniq: true, do: fun),
      for({:validate, fun} <- funs, uniq: true, do: fun)
    }
  end

  defp struct_ast(fields) do
    Enum.map(fields, fn
      {name, {:simple, _type}} -> {name, nil}
      {name, {:estructura, module}} -> {name, struct!(module, [])}
    end)
  end

  defp generator_ast(fields) do
    Enum.map(fields, fn
      {name, {:simple, type}} -> {name, stream_data_type_for(type)}
      {name, {:estructura, module}} -> {name, {module, :__generator__, []}}
    end)
  end

  defp stream_data_type_for({:string, kind}),
    do: {StreamData, :string, [kind]}

  defp stream_data_type_for(:string),
    do: stream_data_type_for({:string, :alphanumeric})

  defp stream_data_type_for(type) when is_atom(type),
    do: {StreamData, type, []}

  defp stream_data_type_for({_, _, _} = type),
    do: type

  # AST for the module which is currently being created
  defp module_ast(module, fields, %{funs: funs, defs: defs}) do
    {coercions, validations} = coercions_and_validations(funs)
    struct = struct_ast(fields)
    generator = generator_ast(fields)

    [
      quote do
        defstruct unquote(Macro.escape(struct))
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
