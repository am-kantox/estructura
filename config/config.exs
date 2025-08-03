import Config

if Mix.env() in [:dev, :test, :ci] do
  config :ex_money, default_cldr_backend: Estructura.Cldr
end
