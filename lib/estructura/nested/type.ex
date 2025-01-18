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
end
