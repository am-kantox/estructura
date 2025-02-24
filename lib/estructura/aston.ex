defmodule Estructura.Aston do
  @moduledoc """
  The implementation of `Estructura` ready to work with tree AST-like structure
  """

  alias Estructura.Aston

  @max_children Application.compile_env(:estructura, :tree_children_generate_count, 7)

  use Estructura,
    access: true,
    coercion: true,
    validation: true,
    enumerable: true,
    collectable: :content,
    generator: [
      name: {StreamData, :string, [:alphanumeric]},
      attributes:
        {StreamData, :map_of,
         [
           {StreamData, :atom, [:alphanumeric]},
           {StreamData, :one_of,
            [
              [
                {StreamData, :integer},
                {StreamData, :boolean},
                {StreamData, :string, [:alphanumeric]}
              ]
            ]}
         ]},
      content: {StreamData, :tree, [{StreamData, :fixed_list, [[]]}, &Aston.child_gen/1]}
    ]

  if {:module, Jason} == Code.ensure_compiled(Jason) do
    @derive {Jason.Encoder, only: ~w|name attributes content|a}
  end

  @derive {Estructura.Flattenable, only: ~w|name attributes content|a}

  defstruct name: nil, attributes: %{}, content: []

  @type t :: %{
          __struct__: Aston,
          name: atom() | binary(),
          attributes: map(),
          content: nil | binary() | [binary() | Aston.t()]
        }

  @impl Aston.Coercible
  def coerce_name(value) when is_binary(value), do: {:ok, value}

  def coerce_name(value) when is_list(value) do
    {:ok, Enum.join(value, ".")}
  rescue
    e in [Estructura.Error] ->
      {:error, Exception.message(e)}
  end

  def coerce_name(value) do
    case String.Chars.impl_for(value) do
      nil -> {:error, "Cannot coerce value given for `name` field (#{inspect(value)})"}
      impl -> {:ok, impl.to_string(value)}
    end
  end

  @impl Aston.Coercible
  def coerce_attributes(nil), do: {:ok, %{}}
  def coerce_attributes(value) when is_map(value), do: {:ok, value}
  def coerce_attributes(value) when is_list(value), do: {:ok, Map.new(value)}
  def coerce_attributes({key, value}), do: {:ok, %{key => value}}

  def coerce_attributes(value),
    do: {:error, "Cannot coerce value given for `attributes` field (#{inspect(value)})"}

  @impl Aston.Coercible
  def coerce_content(nil), do: {:ok, nil}
  def coerce_content(true), do: {:ok, true}
  def coerce_content(false), do: {:ok, false}
  def coerce_content(number) when is_number(number), do: {:ok, number}
  def coerce_content(text) when is_binary(text), do: {:ok, text}
  def coerce_content(value), do: value |> List.wrap() |> do_coerce_content({[], []})

  defp do_coerce_content([], {good, []}), do: {:ok, Enum.reverse(good)}

  defp do_coerce_content([], {_, bad}),
    do: {:error, "The following elements could not be coerced: #{inspect(bad)}"}

  defp do_coerce_content([head | rest], {good, bad}) when head in [true, false, nil],
    do: do_coerce_content(rest, {[head | good], bad})

  defp do_coerce_content([head | rest], {good, bad}) when is_number(head),
    do: do_coerce_content(rest, {[head | good], bad})

  defp do_coerce_content([head | rest], {good, bad}) when is_binary(head),
    do: do_coerce_content(rest, {[head | good], bad})

  defp do_coerce_content([%Aston{} = head | rest], {good, bad}),
    do: do_coerce_content(rest, {[head | good], bad})

  defp do_coerce_content([%{} = head | rest], {good, bad}) do
    case coerce(head) do
      {:ok, result} -> do_coerce_content(rest, {[result | good], bad})
      {:error, _error} -> do_coerce_content(rest, {good, [head | bad]})
    end
  end

  defp do_coerce_content([head | rest], {good, bad}),
    do: do_coerce_content(rest, {good, [head | bad]})

  @impl Aston.Validatable
  def validate_name(value) when is_binary(value), do: {:ok, value}
  def validate_name(value), do: {:error, ":name must be a binary, ‹#{inspect(value)}› given"}

  @impl Aston.Validatable
  def validate_attributes(value) when is_map(value), do: {:ok, value}

  def validate_attributes(value),
    do: {:error, ":attributes must be a map, ‹#{inspect(value)}› given"}

  @impl Aston.Validatable
  def validate_content(nil), do: {:ok, nil}
  def validate_content(true), do: {:ok, true}
  def validate_content(false), do: {:ok, false}
  def validate_content(number) when is_number(number), do: {:ok, number}
  def validate_content(text) when is_binary(text), do: {:ok, text}
  def validate_content(value) when is_list(value), do: {:ok, value}

  def validate_content(value),
    do: {:error, ":content must be a nil, a binary, or a list, ‹#{inspect(value)}› given"}

  @doc """
  Coerces the deeply nested map to an instance of nested `Estructura.Aston`
  """
  @spec coerce(any(), keyword(), nil | any()) :: {:ok, value} | {:error, reason}
        when value: any(), reason: String.t()
  def coerce(term, opts \\ [], root \\ nil)

  def coerce(tree, opts, nil),
    do: coerce(tree, opts, tree)

  def coerce(%Aston{} = tree, opts, root),
    do: tree |> Map.from_struct() |> coerce(opts, root)

  def coerce(f, opts, root) when is_function(f, 1),
    do: apply_coercers(f.(root), opts, root)

  def coerce(nil, opts, root),
    do: apply_coercers(nil, opts, root)

  def coerce(bool_node, opts, root) when bool_node in [true, false],
    do: apply_coercers(bool_node, opts, root)

  def coerce(number_node, opts, root) when is_number(number_node),
    do: apply_coercers(number_node, opts, root)

  def coerce(text_node, opts, root) when is_binary(text_node),
    do: apply_coercers(text_node, opts, root)

  def coerce(list, opts, root) when is_list(list) do
    result = Enum.map(list, &coerce(&1, opts, root))

    case Enum.split_with(result, &match?({:error, _}, &1)) do
      {[], result} -> {:ok, Enum.map(result, &elem(&1, 1))}
      {errors, _} -> {:error, Enum.map_join(errors, "\n", &elem(&1, 1))}
    end
  end

  def coerce(%{} = map, opts, root) do
    name = Map.get_lazy(map, :name, fn -> Map.get(map, "name") end)
    {key_prefix, opts} = Keyword.pop(opts, :key_prefix, [])
    key_prefix = key_prefix ++ List.wrap(name)

    result =
      map
      |> Map.split(~w|name attributes content| ++ ~w|name attributes content|a)
      |> case do
        {map, empty} when %{} == empty ->
          Map.new(map, fn
            {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
            {k, v} when is_atom(k) -> {k, v}
          end)

        {_, non_empty} ->
          keys = non_empty |> Map.keys() |> Enum.map(&Enum.join(key_prefix ++ [&1], "."))

          raise KeyError,
            key: key_prefix,
            term: non_empty,
            message: "Unknown fields: #{inspect(keys)}"
      end
      |> Enum.reduce(%Aston{}, fn {k, v}, acc ->
        k
        |> case do
          :content -> coerce(v, Keyword.put(opts, :key_prefix, key_prefix), root)
          _ -> {:ok, v}
        end
        |> case do
          {:ok, v} -> put!(acc, k, v)
          {:error, reason} -> raise KeyError, key: k, term: v, message: reason
        end
      end)

    {:ok, result}
  rescue
    e in [Estructura.Error, KeyError] ->
      {:error, Exception.message(e)}
  end

  def coerce(term, opts, _root),
    do: {:error, "Unknown term at #{inspect(opts)}: ‹#{inspect(term)}›"}

  @spec apply_coercers(any(), keyword(), any()) :: {:ok, value} | {:error, reason}
        when value: any(), reason: String.t()
  defp apply_coercers(term, opts, _root) do
    key = Keyword.get(opts, :key_prefix)

    opts
    |> Keyword.get(:coercers, [])
    |> Enum.to_list()
    |> Enum.reduce_while({:ok, term}, fn
      {^key, f}, {:ok, term} when is_function(f, 1) -> {:cont, f.(term)}
      _, {:ok, _} = acc -> {:cont, acc}
      _, {:error, _} = error -> {:halt, error}
    end)
  end

  @doc """
  Returns the key to be used for accessing the nested element(s)
  """
  def access(%Aston{name: root}, [root | path]), do: access(path)
  def access(%Aston{}, path), do: access(path)

  @doc false
  def access(path) when is_list(path) do
    Enum.flat_map(path, fn e -> [:content, Access.filter(&match?(%Aston{name: ^e}, &1))] end)
  end

  @doc false
  def root(%Aston{name: name}), do: name

  @doc """
  Converts `Estructura.Aston` to the XML AST understandable by `XmlBuilder`
  """
  @spec to_ast(t()) :: {element, map(), content}
        when element: atom() | binary(), content: nil | binary() | list()
  def to_ast(%Aston{} = tree), do: ast_content(tree)

  defp ast_content(%Aston{name: name, attributes: attributes, content: content}),
    do: {name, attributes, ast_content(content)}

  defp ast_content(nil), do: ""
  defp ast_content(true), do: true
  defp ast_content(false), do: false
  defp ast_content(number) when is_number(number), do: number
  defp ast_content(text_node) when is_binary(text_node), do: text_node
  defp ast_content(list) when is_list(list), do: Enum.map(list, &ast_content/1)

  @doc false
  def child_gen(_child) do
    StreamData.list_of(
      StreamData.frequency([
        {1, nil},
        {2, StreamData.string(:alphanumeric)},
        {7, Aston.__generator__()}
      ]),
      max_length: @max_children
    )
  end
end
