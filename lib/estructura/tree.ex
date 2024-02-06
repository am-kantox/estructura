defmodule Estructura.Tree do
  @moduledoc """
  The implementation of `Estructura` ready to work with tree AST-like structure
  """

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
      content:
        {StreamData, :tree, [{StreamData, :fixed_list, [[]]}, &Estructura.Tree.child_gen/1]}
    ]

  if {:module, Jason} == Code.ensure_compiled(Jason) do
    @derive {Jason.Encoder, only: ~w|name attributes content|a}
  end

  @derive {Estructura.Flattenable, only: ~w|name attributes content|a}

  defstruct name: nil, attributes: %{}, content: []

  @type t :: %{
          __struct__: Estructura.Tree,
          name: atom() | binary(),
          attributes: map(),
          content: nil | binary() | [binary() | Estructura.Tree.t()]
        }

  @impl Estructura.Tree.Coercible
  def coerce_name(value) when is_binary(value), do: {:ok, value}

  def coerce_name(value) when is_list(value) do
    {:ok, Enum.join(value, ".")}
  rescue
    e in [ArgumentError] ->
      {:error, Exception.message(e)}
  end

  def coerce_name(value) do
    case String.Chars.impl_for(value) do
      nil -> {:error, "Cannot coerce value given for `name` field (#{inspect(value)})"}
      impl -> {:ok, impl.to_string(value)}
    end
  end

  @impl Estructura.Tree.Coercible
  def coerce_attributes(nil), do: {:ok, %{}}
  def coerce_attributes(value) when is_map(value), do: {:ok, value}
  def coerce_attributes(value) when is_list(value), do: {:ok, Map.new(value)}
  def coerce_attributes({key, value}), do: {:ok, %{key => value}}

  def coerce_attributes(value),
    do: {:error, "Cannot coerce value given for `attributes` field (#{inspect(value)})"}

  @impl Estructura.Tree.Coercible
  def coerce_content(nil), do: {:ok, nil}
  def coerce_content(text) when is_binary(text), do: {:ok, text}
  def coerce_content(value), do: value |> List.wrap() |> do_coerce_content({[], []})

  defp do_coerce_content([], {good, []}), do: {:ok, Enum.reverse(good)}

  defp do_coerce_content([], {_, bad}),
    do: {:error, "The following elements could not be coerced: #{inspect(bad)}"}

  defp do_coerce_content([head | rest], {good, bad}) when is_binary(head),
    do: do_coerce_content(rest, {[head | good], bad})

  defp do_coerce_content([%Estructura.Tree{} = head | rest], {good, bad}),
    do: do_coerce_content(rest, {[head | good], bad})

  defp do_coerce_content([%{} = head | rest], {good, bad}) do
    case coerce(head) do
      {:ok, result} -> do_coerce_content(rest, {[result | good], bad})
      {:error, _error} -> do_coerce_content(rest, {good, [head | bad]})
    end
  end

  defp do_coerce_content([head | rest], {good, bad}),
    do: do_coerce_content(rest, {good, [head | bad]})

  @impl Estructura.Tree.Validatable
  def validate_name(value) when is_binary(value), do: {:ok, value}
  def validate_name(value), do: {:error, ":name must be a binary, ‹#{inspect(value)}› given"}

  @impl Estructura.Tree.Validatable
  def validate_attributes(value) when is_map(value), do: {:ok, value}

  def validate_attributes(value),
    do: {:error, ":attributes must be a map, ‹#{inspect(value)}› given"}

  @impl Estructura.Tree.Validatable
  def validate_content(nil), do: {:ok, nil}
  def validate_content(text) when is_binary(text), do: {:ok, text}
  def validate_content(value) when is_list(value), do: {:ok, value}

  def validate_content(value),
    do: {:error, ":content must be a nil, a binary, or a list, ‹#{inspect(value)}› given"}

  @doc """
  Coerces the deeply nested map to an instance of nested `Estructura.Tree`
  """
  @spec coerce(any(), [String.t()]) :: {:ok, value} | {:error, reason}
        when value: any(), reason: String.t()
  def coerce(term, key_prefix \\ [])

  def coerce(%Estructura.Tree{} = tree, key_prefix),
    do: tree |> Map.from_struct() |> coerce(key_prefix)

  def coerce(nil, _key_prefix),
    do: {:ok, nil}

  def coerce(text_node, _key_prefix) when is_binary(text_node),
    do: {:ok, text_node}

  def coerce(list, key_prefix) when is_list(list) do
    result = Enum.map(list, &coerce(&1, key_prefix))

    case Enum.split_with(result, &match?({:error, _}, &1)) do
      {[], result} -> {:ok, Enum.map(result, &elem(&1, 1))}
      {errors, _} -> {:error, Enum.map_join(errors, "\n", &elem(&1, 1))}
    end
  end

  def coerce(%{} = map, key_prefix) do
    result =
      map
      |> Map.split([:name, :attributes, :content])
      |> case do
        {map, empty} when %{} == empty ->
          map

        {_, non_empty} ->
          keys = non_empty |> Map.keys() |> Enum.map(&Enum.join(key_prefix ++ [&1], "."))

          raise KeyError,
            key: key_prefix,
            term: non_empty,
            message: "Unknown fields: #{inspect(keys)}"
      end
      |> Enum.reduce(%Estructura.Tree{}, fn {k, v}, acc ->
        case if(k == :content, do: coerce(v, key_prefix ++ [:content]), else: {:ok, v}) do
          {:ok, v} -> put_in(acc, [k], v)
          {:error, reason} -> raise KeyError, key: k, term: v, message: reason
        end
      end)

    {:ok, result}
  rescue
    e in [ArgumentError, KeyError] ->
      {:error, Exception.message(e)}
  end

  def coerce(term, key_prefix),
    do: {:error, "Unknown term at #{inspect(key_prefix)}: ‹#{inspect(term)}›"}

  @doc """
  Converts `Estructura.Tree` to the XML AST understandable by `XmlBuilder`
  """
  @spec to_ast(t()) :: {element, map(), content}
        when element: atom() | binary(), content: nil | binary() | list()
  def to_ast(%Estructura.Tree{} = tree), do: ast_content(tree)

  defp ast_content(%Estructura.Tree{name: name, attributes: attributes, content: content}),
    do: {name, attributes, ast_content(content)}

  defp ast_content(nil), do: nil
  defp ast_content(text_node) when is_binary(text_node), do: text_node
  defp ast_content(list) when is_list(list), do: Enum.map(list, &ast_content/1)

  @doc false
  def child_gen(_child) do
    StreamData.list_of(
      StreamData.frequency([
        {1, nil},
        {2, StreamData.string(:alphanumeric)},
        {7, Estructura.Tree.__generator__()}
      ]),
      max_length: @max_children
    )
  end
end
