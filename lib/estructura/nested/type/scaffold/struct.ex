defmodule Estructura.Nested.Type.Struct do
  @moduledoc """
  `Estructura` type scaffold for creating validatable and coercible types for structs.

  This module provides a way to create custom types for structs.

  ## Usage

  There are two ways to use this type scaffold:

  ### 1. Using the module directly

      iex> require Estructura.Nested.Type.Struct
      ...> Estructura.Nested.Type.Struct.type_module_ast(Type.Money, [origin: Money]
      ...> apply(Type.Money, :validate, [Money.new!("100", :USD)])
      {:ok, :pending}
      iex> apply(Status, :validate, [:invalid])
      {:error, "Expected :invalid to be an instance of `Money` struct"}

  ### 2. Using the `use` macro

      iex> defmodule Price do
      ...>   use Estructura.Nested.Type.Struct, origin: Money
      ...> end
      ...> Role.validate(:admin)
      {:ok, :admin}

  ## Configuration Options

  The scaffold accepts the following options:

  - `:origin` - (required) The actual struct to be wrapped
  - `:coercer` - (optional) Function to coerce input values
  - `:encoder` - (optional) Function to encode values for JSON

  ### Example with Custom Coercion

      defmodule Price do
        use Estructura.Nested.Type.Struct,
          origin: Money,
          coercer: fn
            %Money{} = price -> {:ok, price}
            {amount, currency} -> with %Money{} = price <- Money.new(amount, currency), do: {:ok, price}
            other -> {:error, "Cannot coerce \#{inspect(other)} to price"}
          end
      end

  ## Generated Functions

  The scaffold implements the `Estructura.Nested.Type` behaviour and provides:

  - `generate/1` - Generates random values from the enum for testing
  - `coerce/1` - Attempts to convert input into a valid enum value
  - `validate/1` - Ensures a value is part of the enum

  ### Generation Options

  #### TBD
  """

  defmodule Gen do
    @moduledoc false
    defmacro type_module_ast(opts) do
      opts = Macro.expand(opts, __CALLER__)

      quote generated: true, location: :keep, bind_quoted: [opts: opts] do
        @moduledoc false

        {origin, coercer, encoder, generator} =
          if Keyword.keyword?(opts) do
            {
              Keyword.fetch!(opts, :origin),
              Keyword.get(opts, :coercer),
              Keyword.get(opts, :encoder),
              Keyword.get(opts, :generator)
            }
          else
            {opts, nil, nil, nil}
          end

        @behaviour Estructura.Nested.Type
        case generator do
          generator when is_function(generator, 2) ->
            @impl true
            def generate(opts \\ [], payload \\ []),
              do: unquote(Macro.escape(generator)).(opts, payload)

          _ ->
            nil
        end

        @impl true
        case coercer do
          fun when is_function(fun, 1) ->
            def coerce(term), do: unquote(Macro.escape(coercer)).(term)

          nil ->
            def coerce(term), do: {:ok, term}

          atom when is_atom(atom) ->
            def coerce(term), do: unquote(Macro.escape(coercer)).coerce(term)

          other ->
            def coerce(term), do: {:error, {:unexpected_coercer, other}}
        end

        @impl true
        def validate(term) when is_struct(term, unquote(origin)), do: {:ok, term}

        def validate(other),
          do:
            {:error,
             "Expected #{inspect(other)} to be an instance of: " <> inspect(unquote(origin))}

        if match?({:module, Jason.Encoder}, Code.ensure_compiled(Jason.Encoder)) and
             is_function(encoder, 2) do
          defimpl Jason.Encoder do
            @moduledoc false
            def encode(term, opts), do: unquote(Macro.escape(encoder)).(term, opts)
          end
        end
      end
    end
  end

  @behaviour Estructura.Nested.Type.Scaffold

  @doc """
  Creates a new struct type module with the given name and options.

  ## Options

  See the module documentation for available options.

  ## Examples

  ```elixir
  Estructura.Nested.Type.Struct.type_module_ast(__MODULE__, origin: Money)
  ```
  """
  @impl true
  def type_module_ast(name, opts) when is_list(opts) do
    defmodule name do
      @moduledoc false

      require Gen
      Gen.type_module_ast(opts)
    end
  end

  @doc """
  Implements the struct type directly in the current module.

  ## Options

  See the module documentation for available options.

  ## Examples

      defmodule Price do
        use Estructura.Nested.Type.Struct, origin: Money
      end
  """
  defmacro __using__(opts) do
    quote do
      require Gen
      Gen.type_module_ast(unquote(opts))
    end
  end
end
