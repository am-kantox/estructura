defmodule Estructura.Nested.Type do
  @moduledoc """
  The type to be used for coercing, validating, and generation
    of the implementation’s instances.
  """

  @doc "The generator for the type"
  @callback generate() :: StreamData.t(any())

  @doc "The generator for the type accepting options"
  @callback generate(keyword()) :: StreamData.t(any())

  @doc "Coerces the value coming from outside"
  @callback coerce(term()) :: {:ok, term()} | {:error, any()}

  @doc "Validates the value as being correct"
  @callback validate(term()) :: {:ok, term()} | {:error, any()}

  defmodule Scaffold do
    @moduledoc false

    @callback type_module_ast(name :: module(), opts :: keyword()) :: Macro.t()

    @spec create(module(), module(), keyword()) :: module() | false
    def create(scaffold, name, options) do
      with true <- is_atom(scaffold),
           true <- Code.ensure_loaded?(scaffold),
           true <- function_exported?(scaffold, :type_module_ast, 2),
           {:module, module, _bytecode, _} <-
             scaffold.type_module_ast(name, options),
           do: module
    end
  end
end
