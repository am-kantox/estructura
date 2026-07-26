defmodule Estructura.WIA do
  @moduledoc ~S"""
  `Estructura.WIA` (With Indifferent Access) provides a struct-like container
    that can be accessed by both atom and binary keys, replicating
    Ruby's `Hash#with_indifferent_access` pattern.

  Internally, keys are always stored as atoms. Both atom and binary keys
    are accepted in `Access` operations and normalized to atoms transparently.

  This module builds on top of `Estructura`, reusing its `Access` implementation,
    coercion, validation, and `Enumerable` protocol. It adds indifferent key
    normalization, and implements `Inspect`, `Collectable`, and optionally
    `Jason.Encoder` protocols to mimic map behaviour.

  ## Usage

  ```elixir
  defmodule MyWIA do
    use Estructura.WIA,
      fields: [
        foo: [default: 42],
        bar: [default: ""],
        baz: [default: %{}]
      ]

    @impl MyWIA.Coercible
    def coerce_foo(value) when is_integer(value), do: {:ok, value}
    def coerce_foo(value) when is_binary(value) do
      case Integer.parse(value) do
        {int, ""} -> {:ok, int}
        _ -> {:error, "not a valid integer"}
      end
    end

    @impl MyWIA.Validatable
    def validate_foo(value) when value >= 0, do: {:ok, value}
    def validate_foo(_), do: {:error, ":foo must be non-negative"}
  end
  ```

  Then both atom and binary keys work interchangeably:

  ```elixir
  wia = %MyWIA{}
  wia[:foo]        #=> 42
  wia["foo"]       #=> 42
  put_in(wia, ["foo"], 100)  #=> %MyWIA{foo: 100, ...}
  ```

  ## Options

  * `fields` — a keyword list of `{field_name, opts}` where `opts` is a keyword list with:
    * `:default` — the default value for the field (default: `nil`)
    * `:coerce` — whether to generate a coercion callback for this field (default: `false`)
    * `:validate` — whether to generate a validation callback for this field (default: `false`)

  ## Protocols

  `Inspect`, `Enumerable`, and `Collectable` protocols are automatically
    implemented to mimic plain map behaviour.
  If `Jason` is compiled and available, `Jason.Encoder` is also derived.
  """

  @doc false
  defmacro __using__(opts) do
    field_specs = Keyword.get(opts, :fields, [])

    unless Keyword.keyword?(field_specs) do
      raise CompileError,
        description:
          "`use Estructura.WIA` expects `fields` to be a keyword list, got: #{inspect(field_specs)}"
    end

    field_names = Keyword.keys(field_specs)

    defaults =
      Enum.map(field_specs, fn {name, spec} ->
        {name, Keyword.get(spec, :default, nil)}
      end)

    coerced_fields =
      for {name, spec} <- field_specs,
          Keyword.get(spec, :coerce, false),
          do: name

    validated_fields =
      for {name, spec} <- field_specs,
          Keyword.get(spec, :validate, false),
          do: name

    estructura_opts = [
      access: true,
      enumerable: true,
      indifferent: true,
      coercion: if(coerced_fields == [], do: false, else: coerced_fields),
      validation: if(validated_fields == [], do: false, else: validated_fields)
    ]

    quote bind_quoted: [
            estructura_opts: estructura_opts,
            defaults: defaults,
            field_names: field_names
          ] do
      use Estructura, estructura_opts

      defstruct defaults

      @__wia_fields__ field_names
      @before_compile {Estructura.WIA, :inject_wia_protocols}
    end
  end

  @doc false
  defmacro inject_wia_protocols(env) do
    fields = Module.get_attribute(env.module, :__wia_fields__)
    wia_protocol_ast(fields) ++ List.wrap(wia_jason_ast(fields))
  end

  #############################################################################
  ## Protocols: Inspect, Collectable
  #############################################################################

  @doc false
  @spec wia_protocol_ast([atom()]) :: [Macro.t()]
  defp wia_protocol_ast(fields) do
    [
      quote generated: true, location: :keep, bind_quoted: [fields: fields] do
        module = __MODULE__

        defimpl Inspect do
          @moduledoc false
          import Inspect.Algebra

          def inspect(%unquote(module){} = wia, opts) do
            map_contents =
              for key <- unquote(fields) do
                key_doc = Inspect.Algebra.color("#{key}:", :atom, opts)
                concat(key_doc, concat(" ", to_doc(Map.get(wia, key), opts)))
              end

            container_doc(
              "%#{Kernel.inspect(unquote(module))}{",
              map_contents,
              "}",
              opts,
              fn doc, _opts -> doc end
            )
          end
        end

        defimpl Collectable do
          @moduledoc false

          def into(%unquote(module){} = wia) do
            fun = fn
              list, {:cont, {key, value}} ->
                case unquote(module).normalize_key(key) do
                  {:ok, atom_key} -> [{atom_key, value} | list]
                  :error -> raise KeyError, key: key, term: wia
                end

              list, :done ->
                Enum.reduce(list, wia, fn {key, value}, s ->
                  unquote(module).put!(s, key, value)
                end)

              _list, :halt ->
                :ok
            end

            {[], fun}
          end
        end
      end
    ]
  end

  #############################################################################
  ## Jason
  #############################################################################

  @doc false
  @spec wia_jason_ast([atom()]) :: Macro.t() | nil
  defp wia_jason_ast(fields) do
    if Code.ensure_compiled(Jason) == {:module, Jason} do
      quote generated: true, location: :keep, bind_quoted: [fields: fields] do
        module = __MODULE__

        defimpl Jason.Encoder do
          @moduledoc false

          def encode(%unquote(module){} = wia, opts) do
            map =
              for key <- unquote(fields), into: %{} do
                {key, Map.get(wia, key)}
              end

            Jason.Encode.map(map, opts)
          end
        end
      end
    end
  end
end
