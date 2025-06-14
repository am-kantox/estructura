defmodule Estructura.Lazy do
  @moduledoc """
  The field stub allowing lazy instantiation of `Estructura` fields.
  """

  alias Estructura.Lazy

  @type key :: Map.key()

  @type value :: Map.value()

  @type cached :: {:ok, value()} | {:error, any()}

  @type getter :: (value() -> cached()) | (key(), value() -> cached())

  @type t :: %{
          __struct__: __MODULE__,
          expires_in: non_neg_integer() | :instantly | :never,
          timestamp: nil | DateTime.t(),
          payload: any(),
          value: cached(),
          getter: getter()
        }

  defstruct getter: &Estructura.Lazy.id/1,
            expires_in: :never,
            timestamp: nil,
            payload: nil,
            value: {:error, :not_loaded},
            error: nil

  @spec new(getter(), non_neg_integer() | :instantly | :never) :: t()
  @doc "Create the new struct with the getter passed as an argument"
  def new(getter, expires_in \\ :never) when is_function(getter, 1) or is_function(getter, 2),
    do: struct!(__MODULE__, getter: getter, expires_in: expires_in)

  @spec apply(t(), %{__lazy_data__: term()} | term(), key()) :: t()
  @doc """
  Apply the lazy getter to the data passed as an argument

  ## Examples

      iex> lazy = Estructura.Lazy.new(&System.fetch_env/1)
      ...> Estructura.Lazy.apply(lazy, "LANG").value
      System.fetch_env("LANG")
  """
  def apply(lazy, lazy_data, key \\ nil)

  def apply(%Lazy{expires_in: :never, timestamp: timestamp} = lazy, %{__lazy_data__: _data}, _key)
      when not is_nil(timestamp),
      do: lazy

  def apply(%Lazy{} = lazy, %{__lazy_data__: data}, key) do
    if stale?(lazy),
      do: %{lazy | timestamp: DateTime.utc_now(), value: apply_getter(lazy.getter, key, data)},
      else: lazy
  end

  def apply(%Lazy{} = lazy, data, key), do: __MODULE__.apply(lazy, %{__lazy_data__: data}, key)

  defp apply_getter(getter, _key, data) when is_function(getter, 1), do: getter.(data)
  defp apply_getter(getter, key, data) when is_function(getter, 2), do: getter.(key, data)

  @spec stale?(t()) :: boolean()
  @doc "Validates if the value is not stale yet according to `expires_in` setting"
  def stale?(%Lazy{timestamp: nil}), do: true
  def stale?(%Lazy{expires_in: :instantly}), do: true
  def stale?(%Lazy{expires_in: :never}), do: false

  def stale?(%Lazy{expires_in: expires_in, timestamp: timestamp}) when is_integer(expires_in),
    do: DateTime.diff(DateTime.utc_now(), timestamp, :millisecond) > expires_in

  @doc false
  @spec id(data) :: {:ok, data} when data: value()
  def id(data), do: {:ok, data}

  @doc false
  @spec put(t(), value()) :: t()
  def put(%Lazy{} = lazy, value), do: %{lazy | timestamp: DateTime.utc_now(), value: {:ok, value}}

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    def inspect(%Lazy{value: {:ok, value}, expires_in: :never}, opts) do
      if Keyword.get(opts.custom_options, :lazy_marker, false),
        do: concat(["‹✓", to_doc(value, opts), "›"]),
        else: to_doc(value, opts)
    end

    def inspect(%Lazy{value: {:error, error}}, opts),
      do: concat(["‹✗", to_doc([error: error], opts), "›"])

    def inspect(%Lazy{value: {:ok, value}} = lazy, opts) do
      if Lazy.stale?(lazy) do
        concat(["‹✗", to_doc(value, opts), "›"])
      else
        if Keyword.get(opts.custom_options, :lazy_marker, false),
          do: concat(["‹✓", to_doc(value, opts), "›"]),
          else: to_doc(value, opts)
      end
    end
  end
end
