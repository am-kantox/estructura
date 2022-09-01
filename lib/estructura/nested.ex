defmodule Estructura.Nested do
  @moduledoc """
  The nested struct with helpers to easily describe it and produce
    validation, coercion, and generation helpers.
  """

  @actions ~w|coerce validate generate|a

  @doc false
  defmacro __before_compile__(env) do
    quote generated: true, location: :keep do
      nested = Module.get_attribute(unquote(env.module), :__estructura_nested__)

      {shape, nested} = Map.pop!(nested, :shape)
      # impls = nested |> Map.take(actions) |> Map.values() |> List.flatten() |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      impls = for {key, values} when key in unquote(@actions) <- nested, {module, def} <- values, reduce: %{} do
        acc -> Map.update(acc, module, [def], & &1 ++ [def]) # preserve order in which functions were declared
      end
      IO.inspect(impls, label: "Result")
    end
  end

  @doc false
  def normalize([do: block]), do: normalize(block)
  def normalize({:__block__, [], clauses}), do: clauses
  def normalize(clauses), do: List.wrap(clauses)

  @doc false
  def reshape(defs, action) when is_list(defs), do: Enum.map(defs, &reshape(&1, action))
  def reshape({:def, meta, [{{:., _, _} = def, submeta, args} | rest]}, action) do
    {def, acc} = expand_def(def)
    {acc, {:def, meta, [{:"#{action}_#{def}", submeta, args} | rest]}}
  end
  def reshape({:def, meta, [{:when, when_meta, [{{:., _, _} = def, submeta, args}, guard]} | rest]}, action) do
    {def, acc} = expand_def(def)
    {acc, {:def, meta, [{:when, when_meta, [{:"#{action}_#{def}", submeta, args}, guard]} | rest]}}
  end

  @doc false
  defp expand_def(def) do
    {def, acc} =
      Macro.postwalk(def, [], fn
        {:., _meta, [{prefix, _, _}, suffix]}, acc -> {suffix, [prefix | acc]}
        e, acc -> {e, acc}
      end)

    {def, acc |> Enum.reverse() |> Enum.map(&to_string/1) |> Enum.map(&Macro.camelize/1) |> Module.concat()}
  end

  @doc false
  defmacro __using__(opts \\ []) do
    quote generated: true, location: :keep, bind_quoted: [opts: opts] do
      import Estructura.Nested
      Module.register_attribute(__MODULE__, :__estructura_nested__, accumulate: false, persist: true)
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
          |> Estructura.Nested.reshape(unquote(name))

        nested = Module.get_attribute(__MODULE__, :__estructura_nested__)
        Module.put_attribute(__MODULE__, :__estructura_nested__, Map.put(nested, unquote(name), opts))
      end
    end
  end)
end
