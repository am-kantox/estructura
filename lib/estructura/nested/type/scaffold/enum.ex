defmodule Estructura.Nested.Type.Enum do
  @moduledoc """
  `Estructura` type for a limited set of values, might be used as an implementation generator.
  """

  defmodule Gen do
    @moduledoc false
    defmacro type_module_ast(opts) do
      opts = Macro.expand(opts, __CALLER__)

      {elements, coercer, encoder} =
        if Keyword.keyword?(opts) do
          {
            opts |> Keyword.fetch!(:elements) |> Macro.escape(),
            opts |> Keyword.get(:coercer) |> Macro.escape(),
            opts |> Keyword.get(:encoder) |> Macro.escape()
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
          StreamData.member_of(only -- except)
        end

        @impl true
        if is_function(unquote(coercer), 1) do
          def coerce(term), do: unquote(coercer).(term)
        else
          def coerce(term), do: {:ok, term}
        end

        @impl true
        def validate(term) when term in @elements, do: {:ok, term}

        def validate(other),
          do: {:error, "Expected #{inspect(other)} to be one of: " <> inspect(@elements)}

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
