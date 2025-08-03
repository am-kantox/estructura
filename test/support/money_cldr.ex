if Mix.env() in [:test, :dev] do
  defmodule Estructura.Cldr do
    @moduledoc false
    use Elixir.Cldr,
      locales: ["en", "ru"],
      default_locale: "en",
      providers: [Cldr.Number, Money]
  end
end

