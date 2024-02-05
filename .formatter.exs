locals_without_parens = [shape: 1]

[
  import_deps: [:stream_data],
  inputs: [
    ".formatter.exs",
    "mix.exs",
    "lib/**/*.ex",
    "test/**/*.exs"
  ],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
