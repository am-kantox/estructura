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
          # NB reverse order in which functions were declared!
          |> update_in([module, :defs], &[def | &1])
          # NB reverse order in which functions were declared!
          |> update_in([module, :funs], &[fun | &1])
      end

    slice(env.module, nil, shape, impls)
  end

  @doc false
  def slice(module, name, %{} = fields, impls) do
    impl = Map.get(impls, module, %{funs: [], defs: []})

    complex =
      for {name, %{} = subslice} <- fields, into: %{} do
        module
        |> Module.concat(name |> to_string() |> Macro.camelize())
        |> slice(name, subslice, impls)
      end

    simple =
      Enum.reduce(fields, %{}, fn
        {_, %{}}, acc -> acc
        {name, type}, acc -> Map.put(acc, name, {:simple, type})
      end)

    ast = module_ast(Map.merge(complex, simple), impl)

    if is_nil(name) do
      ast
    else
      Module.create(module, ast, __ENV__)
      {name, {:estructura, module}}
    end
  end

  @doc false
  def module_ast(fields, %{funs: funs, defs: defs}) do
    coercions = for {:coerce, fun} <- funs, uniq: true, do: fun
    validations = for {:validate, fun} <- funs, uniq: true, do: fun

    quote do
      use Estructura, access: true, coercion: unquote(coercions), validation: unquote(validations)
      # generator: [
      #   foo: {StreamData, :integer, []},
      #   bar: {StreamData, :string, [:alphanumeric]},
      #   baz: {StreamData, :fixed_map,
      #     [[key1: {StreamData, :integer}, key2: {StreamData, :integer}]]},
      #   zzz: &Estructura.Full.zzz_generator/0
      # ]

      defstruct Map.keys(unquote(Macro.escape(fields)))

      unquote(defs)
    end
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
