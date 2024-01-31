Application.put_env(:elixir, :ansi_enabled, true)
IEx.configure(
  colors: [
    eval_result: [:green, :bright] ,
    eval_error: [[:red, :bright, "\n☠️  "]],
    eval_info: [:yellow, :bright ],
  ],
  default_prompt: [
     :green, "%prefix", :white, "|%_{}|", :green, "%counter", " ", :blue, "▶", :reset
  ] |> IO.ANSI.format |> IO.chardata_to_string,
  inspect: [
  #    limit: :infinity,
    pretty: true,
    syntax_colors: [number: :red, atom: :blue, string: :green, boolean: :cyan, nil: :magenta]
  ],
  history_size: -1
)

alias Estructura.Collectable.Bitstring, as: ECB
alias Estructura.Collectable.List, as: ECL
alias Estructura.Collectable.Map, as: ECM
alias Estructura.Collectable.MapSet, as: ECMS

alias Estructura.Full, as: F
alias Estructura.Void, as: V
alias Estructura.LazyInst, as: L

alias Estructura.{Lazy, LazyMap}
