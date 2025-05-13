defmodule Estructura.Nested.Type.Enum do
  @moduledoc """
  `Estructura` type scaffold for creating enumerated types with a limited set of valid values.

  This module provides a way to create custom types that can only contain predetermined values,
  similar to enums in other languages.

  ## Usage

  There are two ways to use this type scaffold:

  ### 1. Using the module directly

      iex> require Estructura.Nested.Type.Enum
      ...> Estructura.Nested.Type.Enum.type_module_ast(Status, [:pending, :active, :completed])
      ...> apply(Status, :validate, [:pending])
      {:ok, :pending}
      iex> apply(Status, :validate, [:invalid])
      {:error, "Expected :invalid to be one of: [:pending, :active, :completed]"}

  ### 2. Using the `use` macro

      iex> defmodule Role do
      ...>   use Estructura.Nested.Type.Enum, elements: [:admin, :user, :guest]
      ...> end
      ...> Role.validate(:admin)
      {:ok, :admin}

  ## Configuration Options

  The scaffold accepts the following options:

  - `:elements` - (required) List of valid values for the enum
  - `:coercer` - (optional) Function to coerce input values
  - `:encoder` - (optional) Function to encode values for JSON

  ### Example with Custom Coercion

      defmodule Status do
        use Estructura.Nested.Type.Enum,
          elements: [:pending, :active, :completed],
          coercer: fn
            str when is_binary(str) -> {:ok, String.to_existing_atom(str)}
            atom when is_atom(atom) -> {:ok, atom}
            other -> {:error, "Cannot coerce \#{inspect(other)} to status"}
          end
      end

  ### Example with Custom JSON Encoding

      defmodule Role do
        use Estructura.Nested.Type.Enum,
          elements: [:admin, :user, :guest],
          encoder: fn role, opts -> Jason.Encode.string(Atom.to_string(role), opts) end
      end

  ## Generated Functions

  The scaffold implements the `Estructura.Nested.Type` behaviour and provides:

  - `generate/1` - Generates random values from the enum for testing
  - `coerce/1` - Attempts to convert input into a valid enum value
  - `validate/1` - Ensures a value is part of the enum

  ### Generation Options

  The `generate/1` function accepts:
  - `:only` - List of elements to generate from (default: all elements)
  - `:except` - List of elements to exclude from generation

  ```elixir
  Role.generate(only: [:admin, :user]) |> Enum.take(1) |> List.first()
  #⇒ :admin # or :user

  Role.generate(except: [:guest]) |> Enum.take(1) |> List.first()
  #⇒ :admin # or :user
  ```
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
          StreamData.member_of(only -- except)
        end

        @impl true
        case unquote(coercer) do
          fun when is_function(fun, 1) ->
            def coerce(term), do: unquote(coercer).(term)

          nil ->
            def coerce(term), do: {:ok, term}

          :atom ->
            def coerce(term), do: Estructura.Coercers.Atom.coerce(term)

          atom ->
            def coerce(term), do: unquote(coercer).coerce(term)

          other ->
            def coerce(term), do: {:error, {:unexpected_coercer, other}}
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

  @doc """
  Creates a new enum type module with the given name and options.

  ## Options

  See the module documentation for available options.

  ## Examples

  ```elixir
  Estructura.Nested.Type.Enum.type_module_ast(__MODULE__, elements: [:pending, :active])
  ```
  """
  @impl true
  def type_module_ast(name, opts) when is_list(opts) do
    defmodule name do
      @moduledoc false
      @opts opts

      @doc false
      def options, do: @opts

      require Gen
      Gen.type_module_ast(@opts)
    end
  end

  @doc """
  Implements the enum type directly in the current module.

  ## Options

  See the module documentation for available options.

  ## Examples

      defmodule Role do
        use Estructura.Nested.Type.Enum, elements: [:admin, :user, :guest]
      end
  """
  defmacro __using__(opts) do
    quote do
      require Gen
      Gen.type_module_ast(unquote(opts))
    end
  end
end
