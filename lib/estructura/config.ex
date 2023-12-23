defmodule Estructura.Config do
  @moduledoc """
  The configuration of the `Estructura` that is built from the parameters,
  passed as a second argument in a call to `use Estructura`.

  One normally does not need to meddle with this module.
  """

  @typedoc "The generator to be passed to `use Estructura` should be given in one of these forms"
  @type generator :: {module(), atom()} | {module(), atom(), [any()]} | (-> any())

  @typedoc "The structure key"
  @type key :: atom()

  @typedoc "The structure value"
  @type value :: any()

  @typedoc "The configuration of `Estructura`"
  @type t :: %{
          __struct__: __MODULE__,
          access: boolean(),
          coercion: false | true | [key()],
          validation: false | true | [key()],
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
