defmodule Estructura.Config do
  @moduledoc false

  @typedoc "The generator to be passed to `use Estructura` should be given in one of these forms"
  @type generator :: {module(), atom()} | {module(), atom(), [any()]} | (() -> any())

  @typedoc "The structure key"
  @type key :: atom()

  @typedoc "The configuration of `Estructura`"
  @type t :: %{
          __struct__: __MODULE__,
          access: boolean(),
          coercion: boolean(),
          validation: boolean(),
          colleactable: false | key(),
          enumerable: boolean(),
          generator: [{key(), generator()}]
        }

  defstruct access: true,
            coercion: false,
            validation: false,
            collectable: false,
            enumerable: false,
            generator: false
end
