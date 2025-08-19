# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Estructura is an Elixir library that provides powerful extensions for Elixir structures, including nested structures, validation, coercion, lazy evaluation, and property-based testing support. It's a library focused on enhancing struct functionality with features like Access implementation, type systems, and data transformation capabilities.

## Development Commands

### Core Development Tasks

```bash
# Install dependencies and compile
mix deps.get
mix deps.compile
mix compile

# Run tests
mix test

# Run tests with coverage
mix test --cover

# Run quality checks (format, credo, dialyzer)
mix quality

# Run CI quality checks (includes format check)
mix quality.ci

# Format code (always run as final step per user preferences)
mix format
```

### Individual Quality Tools

```bash
# Check code formatting
mix format --check-formatted

# Run Credo static analysis
mix credo --strict

# Run Dialyzer type checking
mix dialyzer
```

### Testing Commands

```bash
# Run specific test file
mix test test/estructura_test.exs

# Run tests with specific pattern
mix test --only property

# Run doctests
mix test --only doctest

# Generate and view test coverage report
mix test --cover
mix coveralls.html
```

## Architecture

### Core Modules Structure

- **`Estructura`** - Main module providing Access, Enumerable, Collectable implementations
- **`Estructura.Nested`** - Advanced nested structures with validation and type coercion
- **`Estructura.Lazy`** - Lazy evaluation support for deferred computation
- **`Estructura.LazyMap`** - Lazy map implementation with stale value handling
- **`Estructura.Flattenable`** - Protocol for flattening nested structures
- **`Estructura.Transformer`** - Protocol for structure transformation

### Type System

The library includes a rich type system:
- **Built-in types**: DateTime, Date, Time, URI, IP, String, UUID
- **Type scaffolds**: Enum (predefined values), Tags (multiple predefined values), TimeSeries
- **Custom type validation and coercion**

### Key Features Implementation

1. **Access Protocol**: Enables `get_in/2`, `put_in/3`, `update_in/3` operations
2. **Validation System**: Field-level validation with custom rules
3. **Coercion System**: Automatic type conversion during field updates
4. **Property Testing**: StreamData generators for property-based testing
5. **Lazy Evaluation**: Deferred computation with configurable staleness

## Configuration Files

- **`.formatter.exs`** - Elixir code formatting configuration
- **`.credo.exs`** - Static analysis rules (max line length: 120, max complexity: 42)
- **`.dialyzer/ignore.exs`** - Dialyzer warnings to ignore
- **`config/config.exs`** - Application configuration (minimal, mainly for testing)

## Testing Strategy

The project uses comprehensive testing including:
- **Unit tests** with ExUnit
- **Property-based tests** with ExUnitProperties and StreamData
- **Doctests** embedded in module documentation
- **Coverage reporting** with ExCoveralls

Test files are located in `test/` directory with support files in `test/support/`.

## CI/CD Configuration

GitHub Actions workflows:
- **Test workflow** (`.github/workflows/test.yml`): Runs on push/PR, tests against OTP 27 with Elixir 1.17 & 1.18
- **Dialyzer workflow** (`.github/workflows/dialyzer.yml`): Scheduled nightly runs for type checking

## Build and Dependencies

The project supports multiple MIX_ENV configurations:
- **`:dev`** - Development with full test support
- **`:test`** - Testing environment  
- **`:ci`** - Continuous integration with strict checks
- **`:prod`** - Production build (minimal dependencies)

Key dependencies:
- `stream_data` - Property-based testing
- `elixir_uuid` - UUID support
- `lazy_for` - Lazy evaluation utilities
- `jason` - JSON encoding (optional)

## Documentation

- **Main docs**: Generated with ExDoc, available at hexdocs.pm/estructura
- **Cheat sheet**: `stuff/estructura.cheatmd` provides quick reference
- **Examples**: Comprehensive examples in module docs and README
- **Changelog**: Tracked in README.md with version history

## Development Environment Notes

- **Elixir version**: ~> 1.12 (tested with 1.17-1.18)
- **OTP version**: 27 recommended
- **Protocol consolidation**: Disabled in dev/test for faster compilation
- **Dialyzer PLT**: Stored in `.dialyzer/` directory for faster subsequent runs

## Common Development Patterns

When working with this codebase:
1. Always run `mix format` as the final step (per user rule)
2. Use property-based tests for structural validation
3. Implement both `coerce/2` and `validate/2` functions for custom types
4. Follow the nested structure patterns for complex data types
5. Test lazy evaluation scenarios with proper timing considerations
