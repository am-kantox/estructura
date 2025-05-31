defmodule Estructura.Nested.Type.UUID do
  @moduledoc """
  `Estructura` type for `UUID`
  """
  @behaviour Estructura.Nested.Type

  @type t :: %__MODULE__{
          uuid: String.t(),
          binary: binary(),
          type: :default | :hex | :urn,
          version: :unknown | pos_integer(),
          variant: :rfc4122
        }
  defstruct uuid: nil, binary: nil, type: :default, version: :unknown, variant: :rfc4122

  defimpl String.Chars do
    @moduledoc false
    def to_string(%Estructura.Nested.Type.UUID{uuid: value}), do: value
  end

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra
    import Kernel, except: [inspect: 2]

    def inspect(%Estructura.Nested.Type.UUID{uuid: value}, opts) do
      concat([to_doc(value, opts)])
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      @moduledoc false
      def encode(%Estructura.Nested.Type.UUID{uuid: value}, _opts),
        do: [?", value, ?"]
    end
  end

  defimpl Estructura.Transformer do
    @moduledoc false

    def transform(value, _options), do: to_string(value)
  end

  @impl true
  def generate(opts \\ []), do: Estructura.StreamData.uuid(opts)

  @impl true
  def coerce(%__MODULE__{} = term), do: {:ok, term}

  def coerce(term) when is_binary(term) do
    case UUID.info(term) do
      {:ok, info} -> {:ok, struct!(__MODULE__, info)}
      _ -> {:error, "Not valid UUID: #{term}"}
    end
  end

  def coerce(term), do: {:error, "Not valid UUID: " <> inspect(term)}

  @impl true
  def validate(%__MODULE__{uuid: value} = uuid) do
    with {:ok, info} <- UUID.info(value),
         true <- Map.new(info) == Map.from_struct(uuid),
         do: {:ok, uuid},
         else: (_ -> {:error, "Not valid UUID: #{inspect(uuid)}"})
  end

  def validate(other), do: {:error, "Expected UUID, got: " <> inspect(other)}
end
