import Config

if Mix.env() in [:test, :dev] do
  config :ex_money, default_cldr_backend: Estructura.Cldr
end
