  defmodule Estructura.Cldr do
    use Elixir.Cldr,
      locales: ["en", "ru"],
      default_locale: "en",
      providers: [Cldr.Number, Money]
  end

