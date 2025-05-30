defmodule Estructura.Nested.Type.Tags do
  @moduledoc """
  `Estructura` type for a set of predefined values, might be used as an implementation generator.
  """

  defmodule Gen do
    @moduledoc false
    defmacro type_module_ast(opts) do
      opts = Macro.expand(opts, __CALLER__)

      {elements, coercer, encoder} =
        if Keyword.keyword?(opts) do
          {
            Keyword.fetch!(opts, :elements),
            Keyword.get(opts, :coercer),
            Keyword.get(opts, :encoder)
          }
        else
          {opts, nil, nil}
        end

      quote generated: true, location: :keep do
        @moduledoc false
        @elements unquote(elements)

        @behaviour Estructura.Nested.Type
        @impl true
        def generate(opts \\ []) do
          only = Keyword.get(opts, :only, @elements)
          except = Keyword.get(opts, :except, [])

          only
          |> Kernel.--(except)
          |> StreamData.member_of()
          |> StreamData.list_of()
          |> StreamData.map(&Enum.uniq/1)
        end

        @impl true
        case unquote(coercer) do
          fun when is_function(fun, 1) ->
            def coerce(term), do: unquote(coercer).(term)

          nil ->
            def coerce(term), do: {:ok, Enum.uniq(term)}

          :atom ->
            def coerce(term) do
              term
              |> Enum.reduce_while({:ok, []}, fn value, {:ok, result} ->
                case Estructura.Coercers.Atom.coerce(value) do
                  {:ok, value} -> {:cont, {:ok, [value | result]}}
                  {:error, reason} -> {:halt, {:error, reason}}
                end
              end)
              |> case do
                {:ok, results} -> {:ok, results |> Enum.reverse() |> Enum.uniq()}
                other -> other
              end
            end

          atom ->
            def coerce(term), do: unquote(coercer).coerce(term)

          other ->
            def coerce(term), do: {:error, {:unexpected_coercer, other}}
        end

        @impl true
        def validate(term) when is_list(term) do
          if Enum.all?(term, &(&1 in @elements)),
            do: {:ok, term},
            else:
              {:error,
               "All tags are expected to be one of #{inspect(@elements)}. " <>
                 "Unexpected tags: " <> inspect(term -- @elements)}
        end

        def validate(other),
          do: {:error, "Expected #{inspect(other)} to be list of: " <> inspect(@elements)}

        if Code.ensure_loaded?(Jason.Encoder) and is_function(unquote(encoder), 2) do
          defimpl Jason.Encoder do
            @moduledoc false
            def encode(term, opts), do: unquote(encoder).(term, opts)
          end
        end
      end
    end
  end

  @behaviour Estructura.Nested.Type.Scaffold

  @impl true
  def type_module_ast(name, opts) when is_list(opts) do
    defmodule name do
      @moduledoc false
      @opts opts

      require Gen
      Gen.type_module_ast(@opts)
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote do
      require Gen
      Gen.type_module_ast(unquote(opts))
    end
  end
end
