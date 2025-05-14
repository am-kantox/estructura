# Powerful Nested Structures

## The Power of Structured Data

In modern Elixir applications, handling complex nested data structures with proper validation, type coercion, and testing can be challenging. Enter Estructura, a powerful library that brings sophistication to Elixir structs while maintaining their elegant simplicity.

## Core Features

### 1. Sophisticated Nested Structures

Estructura allows you to define and work with deeply nested structures while maintaining full type safety and validation:

```elixir
defmodule User do
  use Estructura.Nested

  shape %{
    name: :string,
    address: %{
      city: :string,
      street: %{name: :string, house: Estructura.Nested.Type.Integer}
    },
    created_at: Estructura.Nested.Type.DateTime,
    tags: Estructura.Nested.Type.Tags
  ]
end
```

### 2. Smart Type System

Built-in types with validation, coercion, and generation capabilities:

- `Estructura.Nested.Type.DateTime` - For timestamp handling
- `Estructura.Nested.Type.Date` - For date values
- `Estructura.Nested.Type.Time` - For time values
- `Estructura.Nested.Type.URI` - For URL/URI validation
- `Estructura.Nested.Type.IP` - For IPv4/IPv6 addresses
- `Estructura.Nested.Type.String` - For string handling
- Custom type scaffolding with `Estructura.Nested.Type.{Tags, Enum}`

```elixir
# Define custom enum type
defmodule Status do
  use Estructura.Nested.Type.Enum,
    elements: [:pending, :active, :completed]
end

# Use in your structure
defmodule Task do
  use Estructura.Nested
  
  shape %{title: :string, status: Status}
end
```

### 3. Powerful Validation

Validate entire structures with a single call:

```elixir
# Define validation rules
defmodule Order do
  use Estructura.Nested

  shape %{amount: :positive_integer, currency: :any}

  validate do
    def amount(value) when value > 0, do: {:ok, value}
    def amount(value), do: {:error, value}

    def currency(value) when value in ~w(USD EUR GBP), do: {:ok, value}
    def currency(value), do: {:error, value}
  end
end

# Validate instances
order = %Order{amount: 100, currency: "USD"}
{:ok, validated} = Order.validate(order)
```

### 4. Intelligent Coercion

Automatically convert data to the right types:

```elixir
defmodule Temperature do
  use Estructura.Nested

  defstruct [:value, :unit]

  def coerce(:value, str) when is_binary(str) do
    case Float.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "Invalid number"}
    end
  end

  def coerce(:unit, unit) when is_binary(unit),
    do: {:ok, String.to_existing_atom(unit)}
end

# Coercion happens automatically
{:ok, temp} = Temperature.cast(%{
  "value" => "23.5",
  "unit" => "celsius"
})
```

### 5. Property-Based Testing

Generate valid test data automatically:

```elixir
defmodule UserTest do
  use ExUnit.Case
  use ExUnitProperties

  property "valid users are validated" do
    check all %User{} = user <- User.__generator__() do
      assert {:ok, ^user} = User.validate(user)
    end
  end
end
```

### 6. Flexible Data Transformation

Transform nested structures into different formats:

```elixir
# Flatten nested structures
flattened = Estructura.Flattenable.flatten(user)
assert flattened["address_city"] == "London"

# Transform to different representation
transformed = Estructura.Transformer.transform(user)
assert transformed[:address][:city] == "London"
```

## Advanced Features

### Lazy Evaluation

Estructura supports lazy value computation with `Estructura.Lazy`:

```elixir
defmodule Cache do
  use Estructura.Nested

  defstruct value: Estructura.Lazy.new(&expensive_computation/1)

  def expensive_computation(_) do
    # This computation only happens when the value is accessed
    :timer.sleep(1000)
    :computed_value
  end
end

# Usage with LazyMap
cache = LazyMap.new(
  [
    foo: Estructura.Lazy.new(&parse_int/1),
    bar: Estructura.Lazy.new(&current_time/1, 100) # Expires after 100ms
  ],
  "42"
)
```

### Calculated Fields

Support for computed fields based on other struct values:

```elixir
defmodule Order do
  use Estructura.Nested

  defstruct [
    items: [],
    tax_rate: 0.20,
    subtotal: 0.0,
    calculated: %{
      total: nil  # Calculated field
    }
  ]

  def calculate(:total, %{subtotal: subtotal, tax_rate: rate}),
    do: subtotal * (1 + rate)
end
```

### Aston Tree Structure

Handle AST-like tree structures with the Aston feature:

```elixir
defmodule XMLDoc do
  use Estructura.Aston

  defstruct content: []
end

# Build and transform tree structures
doc = %XMLDoc{
  content: [
    element: "root",
    attributes: [id: "main"],
    children: [
      [element: "child", content: "text"]
    ]
  ]
}
```

### Auto-splitting Keys

Automatically handle different key formats in input data:

```elixir
defmodule UserPrefs do
  use Estructura.Nested

  defstruct [
    display: %{
      theme: :light,
      font_size: 14
    }
  ]
end

# Both formats work automatically
{:ok, prefs1} = UserPrefs.cast(%{
  display: %{theme: :dark}
})

{:ok, prefs2} = UserPrefs.cast(%{
  "display_theme" => "dark",
  "display_font_size" => "16"
}, split: true)
```

### Enhanced JSON Support

Configure JSON encoding behavior per module:

```elixir
defmodule Document do
  use Estructura.Nested,
    flattenable: true,   # Enable flattening
    jason: true,         # Enable JSON encoding
    transformer: true    # Enable transformation

  defstruct [title: "", content: ""]
end

# Automatically handles JSON encoding/decoding
json = Jason.encode!(%Document{title: "Test"})
{:ok, doc} = Document.cast(Jason.decode!(json))
```

## Latest Features (v1.7+)

### 1. Infrastructure Improvements

The latest version (1.7.0) brings significant improvements to:
- Types system architecture
- URI handling capabilities
- IP address support
- Enhanced scaffolding system

### 2. Improved Type System

The type system now includes:

```elixir
# IP Address handling
defmodule Server do
  use Estructura.Nested

  defstruct [:hostname, :ip]
  
  def type(:ip), do: Estructura.Nested.Type.IP
end

# Create with sigil
server = %Server{
  hostname: "web1",
  ip: ~IP[192.168.1.1]
}

# URI validation
defmodule Website do
  use Estructura.Nested

  defstruct [:url]
  
  def type(:url), do: Estructura.Nested.Type.URI
end

# Automatic validation and coercion
{:ok, site} = Website.cast(%{
  url: "https://example.com"
})
```

### 3. Enhanced JSON Integration

Version 1.6.0 adds flexible JSON transformation options:

```elixir
# Configure JSON transformation
flattened = Estructura.Flattenable.flatten(
  complex_struct,
  jsonify: true  # Convert to JSON-friendly format
)

# Or use a custom module
flattened = Estructura.Flattenable.flatten(
  complex_struct,
  jsonify: MyJSONFormatter
)
```

### 4. Improved Coercion System

New coercion capabilities for various types:

```elixir
defmodule Measurement do
  use Estructura.Nested

  defstruct [:value, :timestamp]

  # Nullable coercer for timestamps
  def type(:timestamp), do: Estructura.Coercers.NullableDatetime
  
  # Float coercion with validation
  def type(:value), do: Estructura.Coercers.Float
end

# Both nil and valid dates work
{:ok, m1} = Measurement.cast(%{
  value: "123.45",
  timestamp: nil
})

{:ok, m2} = Measurement.cast(%{
  value: "123.45",
  timestamp: "2024-01-01T10:00:00Z"
})
```

### 5. Type Scaffolding Improvements

Enhanced scaffolding system for custom types:

```elixir
defmodule Priority do
  use Estructura.Nested.Type.Enum,
    elements: [:low, :medium, :high],
    coercer: fn
      str when is_binary(str) -> {:ok, String.to_existing_atom(str)}
      atom when is_atom(atom) -> {:ok, atom}
      other -> {:error, "Invalid priority: #{inspect(other)}"}
    end
end

defmodule Categories do
  use Estructura.Nested.Type.Tags,
    elements: [:feature, :bug, :docs],
    coercer: fn
      tags when is_list(tags) ->
        {:ok, Enum.map(tags, &String.to_existing_atom/1)}
      other ->
        {:error, "Invalid tags: #{inspect(other)}"}
    end
end
```

### 6. Calculated Fields

Support for dynamically calculated fields:

```elixir
defmodule Invoice do
  use Estructura.Nested

  defstruct [
    items: [],
    tax_rate: 0.21,
    calculated: %{
      subtotal: nil,
      tax: nil,
      total: nil
    }
  ]

  def calculate(:subtotal, %{items: items}),
    do: Enum.sum(Enum.map(items, & &1.price))
    
  def calculate(:tax, %{calculated: %{subtotal: sub}, tax_rate: rate}),
    do: sub * rate
    
  def calculate(:total, %{calculated: %{subtotal: sub, tax: tax}}),
    do: sub + tax
end
```

These improvements make Estructura an even more powerful tool for handling complex data structures in Elixir applications. The enhanced type system, improved coercion capabilities, and flexible JSON handling provide everything needed for sophisticated data management.

## Real-world Use Cases

### API Response Handling

```elixir
defmodule APIResponse do
  use Estructura.Nested

  defstruct [
    data: %{
      items: [],
      meta: %{
        page: 1,
        total: 0
      }
    },
    status: :ok
  ]

  def type(:status), do: ResponseStatus  # Enum type
  def type("data.meta.page"), do: Integer
  def type("data.meta.total"), do: Integer
end

# Parse and validate API responses
{:ok, response} = APIResponse.cast(json_data)
```

### Complex Form Data

```elixir
defmodule RegistrationForm do
  use Estructura.Nested

  defstruct [
    user: %{
      email: "",
      password: "",
      preferences: %{
        notifications: true,
        timezone: "UTC"
      }
    },
    terms_accepted: false
  ]

  def validate("user.email", email),
    do: String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    
  def validate("user.password", pass),
    do: String.length(pass) >= 8
end
```

### Configuration Management

```elixir
defmodule AppConfig do
  use Estructura.Nested

  defstruct [
    database: %{
      host: "localhost",
      port: 5432,
      pool_size: 10
    },
    cache: %{
      ttl: 3600,
      backend: :redis
    }
  ]

  def type("database.port"), do: Integer
  def type("database.pool_size"), do: Integer
  def type("cache.ttl"), do: Integer
  def type("cache.backend"), do: CacheBackend  # Enum type
end
```

## Getting Started

1. Add Estructura to your dependencies:

```elixir
def deps do
  [
    {:estructura, "~> 0.2"},
    …
  ]
end
```

2. Configuration (optional):

```elixir
# In config/config.exs
config :estructura,
  jsonify: true,         # Enable JSON-friendly transformations
  transformer: true      # Enable struct transformations
```

3. Define your structures:

```elixir
defmodule MyApp.User do
  use Estructura.Nested

  defstruct [
    name: "",
    email: "",
    settings: %{
      theme: :light,
      language: "en"
    }
  ]

  # Types
  def type("settings.theme"), do: Theme  # Enum type
  
  # Validation
  def validate(:email, email),
    do: String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    
  # Coercion
  def coerce(:name, name) when is_binary(name),
    do: {:ok, String.trim(name)}
end
```

## Why Choose Estructura?

1. **Type Safety**: Built-in type system with validation and coercion
2. **Nested Handling**: Elegant handling of deeply nested structures
3. **Testing Support**: Automatic test data generation
4. **Flexible Transformation**: Convert between different data representations
5. **Production Ready**: Used in production applications

## Conclusion

Estructura brings the power of sophisticated data handling to Elixir while maintaining the language's elegance and simplicity. Whether you're building APIs, handling form data, or managing complex configurations, Estructura provides the tools you need to work with structured data effectively.

Start using Estructura today and experience the power of proper structure handling in your Elixir applications.

