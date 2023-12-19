# Estructura    [![Kantox ❤ OSS](https://img.shields.io/badge/❤-kantox_oss-informational.svg)](https://kantox.com/)  [![Test](https://github.com/am-kantox/estructura/workflows/Test/badge.svg)](https://github.com/am-kantox/estructura/actions?query=workflow%3ATest)  [![Dialyzer](https://github.com/am-kantox/estructura/workflows/Dialyzer/badge.svg)](https://github.com/am-kantox/estructura/actions?query=workflow%3ADialyzer)

**Extensions for _Elixir_ structures.**

## Installation

```elixir
def deps do
  [
    {:estructura, "~> 0.1"},
    # optionally you might want to add `boundary` library 
    # it is used by `estructura` and many other projects
    # more info: https://hexdocs.pm/boundary
    {:boundary, "~> 0.9", runtime: false}
  ]
end
```
I suggest adding [`boundary`](https://hexdocs.pm/boundary) as a dependency since that is used in this project.

## Changelog
* `0.6.0` — `Estructura.Transform` to produce squeezed representations of nested structs
* `0.5.5` — export declarations of both `Estructura` and `Estructura.Nested` to docs
* `0.5.4` — `Estructura.Nested` allows `cast/1` to cast nested structs from maps
* `0.5.3` — `Estructura.diff/3` now understands maps
* `0.5.2` — `Estructura.diff/3`
* `0.5.1` — [BUG] Fixed `Collectable` and `Enumerable` injected implementations
* `0.5.0` — `Estructura.Nested` for nested structures with validation, coercion, and generation
* `0.4.2` — [BUG] Fixed wrong spec for `put!/3`
* `0.4.1` — `Estructura.LazyMap.keys/1`, `Estructura.LazyMap.fetch_all/1`
* `0.4.0` — `Estructura.Lazy`, `Estructura.LazyMap`
* `0.3.2` — `put!/3`
* `0.3.0` — `coercion` and `validation` are now injected as behaviours
* `0.2.0` — `coercion`, `validation`, `put/3`

## [Documentation](https://hexdocs.pm/estructura)

