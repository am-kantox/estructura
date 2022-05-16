defmodule Estructura.Lazy do
  @moduledoc """
  The field stub allowing lazy instantiation of `Estructura` fields.
  """

  use Boundary

  alias Estructura.Lazy

  @type value :: term()

  @type cached :: {:ok, value()} | {:error, any()}

  @type getter :: (value() -> cached())

  @type t :: %{
          __struct__: __MODULE__,
          expires_in: non_neg_integer() | :imminently | :never,
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

  @spec new(getter(), non_neg_integer() | :imminently | :never) :: t()
  @doc "Create the new struct with the getter passed as an argument"
  def new(getter, expires_in \\ :never) when is_function(getter, 1),
    do: struct!(__MODULE__, getter: getter, expires_in: expires_in)

  @spec apply(t(), %{__lazy_data__: term()}) :: t()
  @doc """
  Apply the lazy getter to the data passed as an argument

  ## Examples

      iex> lazy = Estructura.Lazy.new(&String.to_integer/1)
      ...> Estructura.Lazy.apply(lazy, "42").value
      42
  """
  def apply(%Lazy{expires_in: :never, timestamp: timestamp} = lazy, %{__lazy_data__: _data})
      when not is_nil(timestamp),
      do: lazy

  def apply(%Lazy{} = lazy, %{__lazy_data__: data}) do
    if not is_nil(lazy.timestamp) and is_integer(lazy.expires_in) and
         DateTime.diff(DateTime.utc_now(), lazy.timestamp, :millisecond) <= lazy.expires_in do
      lazy
    else
      %Lazy{lazy | timestamp: DateTime.utc_now(), value: lazy.getter.(data)}
    end
  end

  def apply(%Lazy{} = lazy, data), do: __MODULE__.apply(lazy, %{__lazy_data__: data})

  @doc false
  @spec id(data) :: {:ok, data} when data: value()
  def id(data), do: {:ok, data}

  @doc false
  @spec put(t(), value()) :: t()
  def put(lazy, value), do: %Lazy{lazy | timestamp: DateTime.utc_now(), value: {:ok, value}}

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra

    def inspect(%Lazy{value: {:ok, value}, expires_in: :never}, opts) do
      if Keyword.get(opts.custom_options, :lazy_marker, false),
        do: concat(["‹", to_doc(value, opts), "›"]),
        else: to_doc(value, opts)
    end

    def inspect(%Lazy{value: {:error, error}}, opts),
      do: concat(["‹", to_doc([error: error], opts), "›"])

    def inspect(%Lazy{value: {:ok, value}, timestamp: timestamp, expires_in: expires_in}, opts) do
      if is_integer(expires_in) and
           DateTime.diff(DateTime.utc_now(), timestamp, :millisecond) <= expires_in do
        if Keyword.get(opts.custom_options, :lazy_marker, false),
          do: concat(["‹", to_doc(value, opts), "›"]),
          else: to_doc(value, opts)
      else
        concat(["‹?", to_doc(value, opts), "›"])
      end
    end
  end
end
