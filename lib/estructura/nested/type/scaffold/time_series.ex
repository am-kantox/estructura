defmodule Estructura.Nested.Type.TimeSeries do
  @moduledoc """
  `Estructura` type scaffold for creating time series types, where the value is
    predictable changing with a time.

  This module provides a way to create custom types containing the timestamp,
    “static” values, changing randomly, and the time series type.

  The good example of such a type would be a currency exchange rate.

  ## Usage

  There are two ways to use this type scaffold:

  ### 1. Using the module directly

  Unlike other scaffolded modules, this one is supposed to be created as a standalone
    module using `#{inspect(__MODULE__)}`.

  ### 2. Using the `use` macro

      defmodule Rate do
        use Estructura.Nested.Type.TimeSeries,
          series: [
            value: {:oscillating, average: 1.0, amplitude: 0.3, outliers: 0.4}
          ],
          timestamp: :timestamp
      end

  ## Configuration Options

  The scaffold accepts the following options:

  - `:series` - (required) List of valid values for the time series object
  - `:timestamp` - (optional) the type of timestamp field, allowed: `:mototonic`, `:timestamp`, default `:timestamp` 
  - `:coercer` - (optional) Function to coerce input values
  - `:encoder` - (optional) Function to encode values for JSON

  ### Example with Custom Coercion

      defmodule Rate do
        use Estructura.Nested.Type.TimeSeries,
          series: [
            value: {:oscillating, average: 1.0, amplitude: 0.3, outliers: 0.4}
          ],
          timestamp: :timestamp,
          coercer: fn
            %Decimal{} = decimal -> {:ok, Decimal.to_float(decimal)}
            integer when is_integer(integer) -> {:ok, 1.0 * integer}
            float when is_float(float) -> {:ok, float}
            other -> {:error, "Cannot coerce \#{inspect(other)} to TimeSeries object"}
          end
      end

  ### Example with Custom JSON Encoding

      defmodule Rate do
        use Estructura.Nested.Type.TimeSeries,
          series: [
            value: {:oscillating, average: 1.0, amplitude: 0.3, outliers: 0.4}
          ],
          encoder: fn rate, opts -> Jason.Encode.map(Map.from_struct(rate), opts) end
      end

  ## Generated Functions

  The scaffold implements the `Estructura.Nested.Type` behaviour and provides:

  - `generate/1` - Generates random values from the enum for testing
  - `coerce/1` - Attempts to convert input into a valid enum value
  - `validate/1` - Ensures a value is part of the enum

  ### Generation Options

  The `generate/1` function accepts:
  - `:only` - values to generate for (default: all)
  - `:except` - values to exclude from generation

  ```elixir
  Rate.generate() |> Enum.take(1)
  #⇒ %Rate{
  #    currency: :USD,
  #    counter_currency: :EUR,
  #    timestamp: ~U[2025-7-6T12:00:00Z],
  #    value: 1.1
  #  }
  ```
  """

  defmodule H do
    @moduledoc false

    @doc """
    Generates the next oscillating value based on the previous value.

    The function creates oscillating values between 0 and 1 using a sine wave.

    ## Parameters

    - `acc` - Configuration map containing:
      - `:step` - The step in radians for one step towards (default: none), to allow `period`
      - `:period` - The number of steps to complete one oscillation (basically, `2π / period = step`)
        if both `step` and `period` are given, `step` takes precedence and the warning gets issued
        (`[0,∞)`, default: 10)
      - `:average` - The oscillating baseline (any float, default: 0.0)
      - `:amplitude` - Maximum deviation from `average` (any float, default: 1.0)
      - `:outliers` - The probability of the oulier to happen (`[0, 1)`, default: 0.0)
      - `:phase` - Current phase in the oscillation (internal counter)

    ## Returns

    A tuple `{next_value, updated_acc}` where:
    - `next_value` is a float between `[average-amplitude, average+amplitude]` or an outlier
    - `updated_acc` contains the updated phase counter

    ## Examples

        iex> H.oscillating(%{period: 8, amplitude: 0.3})
        {0.5, %{period: 8, amplitude: 0.3, phase: 1}}
        
        iex> H.oscillating(%{period: 8, amplitude: 0.3, phase: 1})
        {0.71, %{period: 8, amplitude: 0.3, phase: 2}}
    """
    def oscillating(acc) when is_list(acc), do: acc |> Map.new() |> oscillating()

    def oscillating(%{} = acc) do
      average = Map.get(acc, :average, 0.0)
      amplitude = Map.get(acc, :amplitude, 1.0) |> max(0.0)
      outliers = Map.get(acc, :outliers, 0.0)

      period = Map.get(acc, :period, 10)
      step = Map.get(acc, :step, {nil, 2 * :math.pi() / period})

      phase = Map.get(acc, :phase, -1)

      {next_phase, step} =
        case step do
          {nil, float} -> {rem(phase + 1, period), float}
          float -> {phase + 1, float}
        end

      value =
        if :rand.uniform() < outliers,
          do: average - amplitude + amplitude * 2 * :rand.uniform(),
          else: average + amplitude * :math.sin(next_phase * step)

      {value, Map.put(acc, :phase, next_phase)}
    end
  end

  defmodule Gen do
    @moduledoc false
    defmacro type_module_ast(opts) do
      opts = Macro.expand(opts, __CALLER__)
      module = __CALLER__.module

      {series, timestamp, coercer, encoder} =
        if Keyword.keyword?(opts) do
          {
            Keyword.fetch!(opts, :series),
            Keyword.get(opts, :timestamp, :timestamp),
            Keyword.get(opts, :coercer),
            Keyword.get(opts, :encoder)
          }
        else
          {opts, [], :timestamp, nil, nil}
        end

      series =
        Enum.map(series, fn
          {name, {type, opts}} -> {name, {type, opts}}
          {name, type} when is_atom(type) -> {name, {type, []}}
          {name, opts} when is_list(opts) -> {name, {:oscillating, opts}}
          {name, opts_fun} when is_function(opts_fun) -> {name, {:oscillating, opts_fun}}
          name when is_atom(name) -> {name, {:oscillating, []}}
        end)

      keys = [:timestamp | Keyword.keys(series)]

      quote generated: true, location: :keep do
        @moduledoc false
        defstruct unquote(keys)

        defmodule Producer do
          @moduledoc false
          @series unquote(series)
          @timestamp unquote(timestamp)

          def produce(opts \\ [], payload \\ []) do
            series =
              for {name, {kind, defaults}} <- @series do
                defaults =
                  with defaults when is_function(defaults, 1) <- defaults, do: defaults.(payload)

                {name, {kind, Keyword.merge(defaults, Keyword.get(opts, name, []))}}
              end

            Stream.unfold(%{series: series}, fn %{series: series} ->
              {results, series} =
                Enum.reduce(series, {[], []}, fn {name, {kind, config}}, {res, cfg} ->
                  {result, config} = apply(H, kind, [config])
                  {[{name, result} | res], [{name, {kind, config}} | cfg]}
                end)

              timestamp =
                case Keyword.get(opts, :timestamp, @timestamp) do
                  :timestamp -> DateTime.utc_now()
                  :unix -> DateTime.utc_now() |> DateTime.to_unix()
                  :string -> DateTime.utc_now() |> DateTime.to_iso8601()
                end

              {Map.new([
                 {:__struct__, unquote(module)},
                 {:timestamp, timestamp} | results
               ]), %{series: series}}
            end)
          end
        end

        @impl true
        defdelegate produce(opts \\ [], payload \\ []), to: Producer

        @behaviour Estructura.Nested.Type
        @impl true
        def generate(opts \\ [], payload \\ []) do
          {payload_opts, payload} = Keyword.pop(payload, :__opts__, [])
          opts = Keyword.merge(payload_opts, opts)

          {pool, opts} = Keyword.pop(opts, :pool, 100)
          {naive, opts} = Keyword.pop(opts, :naive, false)

          do_generate({naive, pool}, opts, payload)
        end

        defp do_generate({true, pool}, opts, payload) do
          opts
          |> produce(payload)
          |> Enum.take(pool)
          |> StreamData.member_of()
        end

        defp do_generate({false, pool}, opts, payload) do
          %StreamData{
            generator: fn rand_seed, _size ->
              {rand_value, _new_seed} = :rand.uniform_s(1000, rand_seed)
              seed_offset = div(rand_value, 10)

              stream = produce(opts, payload)
              root = stream |> Stream.drop(seed_offset) |> Enum.at(0)

              children =
                stream
                |> Stream.drop(seed_offset + 1)
                |> Stream.take(pool)
                |> Stream.map(fn value ->
                  %StreamData.LazyTree{root: value, children: []}
                end)

              %StreamData.LazyTree{root: root, children: children}
            end
          }
        end

        @impl true
        case unquote(coercer) do
          fun when is_function(fun, 1) ->
            def coerce(term), do: fun.(term)

          nil ->
            def coerce(term), do: {:ok, term}

          coercer when is_atom(coercer) ->
            def coerce(term), do: coercer.coerce(term)

          other ->
            def coerce(term), do: {:error, {:unexpected_coercer, other}}
        end

        @impl true
        # TODO
        def validate(%__MODULE__{} = term), do: {:ok, term}

        def validate(other),
          do: {:error, "Expected #{inspect(other)} to be a " <> inspect(__MODULE__)}

        if match?({:module, Jason.Encoder}, Code.ensure_compiled(Jason.Encoder)) and
             is_function(unquote(encoder), 2) do
          defimpl Jason.Encoder do
            @moduledoc false
            def encode(term, opts), do: unquote(encoder).(term, opts)
          end
        end
      end
    end
  end

  @behaviour Estructura.Nested.Type.Scaffold

  @doc """
  Creates a new enum type module with the given name and options.

  ## Options

  See the module documentation for available options.
  """
  @impl true
  def type_module_ast(name, opts) when is_list(opts) do
    defmodule name do
      @moduledoc false
      @opts opts

      @doc false
      def options, do: @opts

      require Gen
      Gen.type_module_ast(@opts)
    end
  end

  @doc """
  Implements the enum type directly in the current module.

  ## Options

  See the module documentation for available options.

  ## Examples

  ```elixir
  defmodule RateType do
    use Estructura.Nested.Type.TimeSeries,
      series: [value: {:oscillating, &RateType.rate_config/1}],
      timestamp: :timestamp

    def rate_config(_currencies) do
      [average: 1.2, amplitude: 0.3, outliers: 0.2]
    end
  end
  ```

  """
  defmacro __using__(opts) do
    quote do
      require Gen
      Gen.type_module_ast(unquote(opts))
    end
  end
end
