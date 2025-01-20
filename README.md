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
* `1.7.0` — better infrastructure for `Types`, `URI`, `IP`, `Scaffold`
* `1.6.0` — `jsonify: true | module()` option in a call to `Estructura.Flattenable.flatten/2`
* `1.5.0` — no `:formulae` dependency
* `1.4.1` — allow functions of arity 1 in `content` as coercers in a call to `Estructura.Aston.coerce/2`
* `1.4.0` — allow coercers in a call to `Estructura.Aston.coerce/2`
* `1.3.0` — calculated fields for `Estructura` and `Estructura.Nested`
* `1.2.12` — export type from `Estructura.Nested`
* `1.2.11` — nullable coercers
* `1.2.10` — coercers for floats, and date/time values
* `1.2.8` — `Estructura.Tree` → `Estructura.Aston` + `Aston.access/2` to retrieve and access key by names
* `1.2.5` — `use Estructura.Nested flattenable: boolean(), jason: boolean(), transformer: boolean()`
* `1.2.3` — Several `coerce/1` and `validate/1` clauses, default coercers
* `1.2.2` — `Estructura.Flattenable`
* `1.2.1` — Generators for `:datetime` and `:date`
* `1.2.0` — `Estructura.Nested` would attempt to split keys by a delimiter if instructed
* `1.1.0` — `Estructura.Aston` to hold an AST structure, like XML
* `1.0.0` — Elixir v1.16 and deps
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

