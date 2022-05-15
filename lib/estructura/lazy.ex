defmodule Estructura.Lazy do
  @moduledoc """
  The field stub allowing lazy instantiation of `Estructura` fields
  """

  use Boundary

  @type result :: {:ok, any()} | :error

  @type getter :: (data :: term() -> result())

  @type t :: %{
          __struct__: __MODULE__,
          getter: getter()
        }

  @spec new(getter()) :: t()
  @doc "Create the new struct with the getter passed as an argument"
  def new(getter) when is_function(getter, 1) do
    struct!(__MODULE__, getter: getter)
  end

  @spec apply(t() | %{__lazy_data__: any()}, term()) :: result()
  @doc """
  Apply the lazy getter to the data passed as an argument

  ## Examples

      iex> lazy = Estructura.Lazy.new(&String.to_integer/1)
      ...> Estructura.Lazy.apply(lazy, "42")
      42
  """
  def apply(lazy, %{__lazy_data__: data}) do
    lazy.getter.(data)
  end

  def apply(lazy, data) do
    lazy.getter.(data)
  end

  @doc false
  @spec id(data) :: data when data: term()
  def id(data), do: data

  defstruct getter: &Estructura.Lazy.id/1
end
