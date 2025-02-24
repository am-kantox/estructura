defmodule Estructura.Error do
  @moduledoc false

  defexception [:estructura, :type, :key, :value, :reason, :message]

  @impl true
  def message(%__MODULE__{message: nil} = exception) do
    %__MODULE__{estructura: estructura, type: type, key: key, value: value, reason: reason} =
      exception

    type_name = type |> to_string() |> String.capitalize()

    type_name <>
      " error for key ‹" <>
      inspect(key) <>
      "› trying to set value ‹" <>
      inspect(value) <>
      "› in estructura ‹" <> inspect(estructura) <> "› (reason: " <> inspect(reason) <> ")"
  end

  def message(%{message: message}) when is_binary(message), do: message

  @impl true
  def blame(exception, stacktrace) do
    message =
      [
        message(exception),
        "    💡 you might want to implement explicit #{exception.type} handler(s) for :#{exception.key}\n"
      ]
      |> Enum.join("\n")

    {%{exception | message: message}, stacktrace}
  end
end
