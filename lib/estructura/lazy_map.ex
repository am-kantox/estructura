defmodule Estructura.LazyMap do
  @moduledoc """
  The implementation of lazy map implementing lazy `Access` for its keys.

  `Estructura.LazyMap` is backed by the “raw” object and a key-value pairs
    where values might be instances of `Estructura.Lazy`. If this is a case,
    they will be accessed through `Lazy` implementation.

  Values might be also raw values, which makes `LazyMap` a drop-in replacement
    of standard _Elixir_ maps, assuming they are accessed through `Access`
    only (e. g. `map[:key]` and not `map.key`.)
  """

  @type t :: %{
          __struct__: __MODULE__,
          __lazy_data__: term(),
          data: map()
        }

  defstruct data: %{}, __lazy_data__: nil

  alias Estructura.Lazy

  @behaviour Access

  @impl Access
  def fetch(lazy, key)

  def fetch(%__MODULE__{data: %{} = data} = this, key) when is_map_key(data, key) do
    case Map.get(data, key) do
      %Lazy{} = value ->
        case Lazy.apply(value, this, key) do
          %Lazy{value: {:ok, value}} -> {:ok, value}
          _ -> :error
        end

      value ->
        {:ok, value}
    end
  end

  def fetch(%__MODULE__{}, _), do: :error

  @impl Access
  def pop(lazy, key)

  def pop(%__MODULE__{data: %{} = data} = this, key) when is_map_key(data, key) do
    case Map.get(data, key) do
      %Lazy{} = value ->
        case Lazy.apply(value, this, key) do
          %Lazy{value: {:ok, value}} ->
            {value, %__MODULE__{this | data: Map.delete(data, key)}}

          _ ->
            {nil, this}
        end

      value ->
        {value, %__MODULE__{this | data: Map.delete(data, key)}}
    end
  end

  def pop(%__MODULE__{data: %{}} = this, _), do: {nil, this}

  @impl Access
  def get_and_update(lazy, key, fun)

  def get_and_update(%__MODULE__{data: %{} = data} = this, key, fun) do
    case Map.get(data, key) do
      %Lazy{} = value ->
        case Lazy.apply(value, this, key) do
          %Lazy{value: {:ok, value}} = result ->
            case fun.(value) do
              :pop ->
                pop(this, key)

              {current_value, new_value} ->
                {current_value,
                 %__MODULE__{this | data: Map.put(data, key, Lazy.put(result, new_value))}}
            end

          _ ->
            {nil, data}
        end

      _ ->
        {value, data} = Map.get_and_update(data, key, fun)
        {value, %__MODULE__{this | data: data}}
    end
  end

  @spec new(keyword() | map()) :: t()
  @doc """
  Creates new instance of `LazyMap` with a second parameter being a backed up object,
    which would be used for lazy retrieving data for values, when value is an instance
    of `Estructura.Lazy`.

  ## Examples

      iex> lm = Estructura.LazyMap.new(
      ...>   [int: Estructura.Lazy.new(&Estructura.LazyInst.parse_int/1)], "42")
      ...> get_in lm, [:int]
      42
  """
  def new(initial \\ %{}, lazy_data \\ nil)
  def new(kw, lazy_data) when is_list(kw), do: kw |> Map.new() |> new(lazy_data)
  def new(%{} = map, lazy_data), do: %__MODULE__{data: map, __lazy_data__: lazy_data}

  @spec keys(t()) :: [Map.key()]
  @doc "Returns all the keys of the underlying map"
  @doc since: "0.4.1"
  def keys(%__MODULE__{data: data}), do: Map.keys(data)

  @spec fetch_all(t()) :: t()
  @doc "Eagerly instantiates the data"
  @doc since: "0.4.1"
  def fetch_all(%__MODULE__{} = lazy) do
    lazy
    |> keys()
    |> Enum.reduce({%{}, lazy}, fn key, {result, lazy} ->
      {value, lazy} = get_and_update(lazy, key, &{&1, &1})
      {Map.put(result, key, value), lazy}
    end)
  end

  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra
    alias Estructura.LazyMap

    def inspect(%LazyMap{data: %{} = data}, opts) do
      {_, data} = Map.pop(data, :__lazy_data__)

      if Keyword.get(opts.custom_options, :lazy_marker, false),
        do: concat(["%‹", to_doc(data, opts), "›"]),
        else: to_doc(data, opts)
    end
  end
end
