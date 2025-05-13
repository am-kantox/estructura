defmodule Estructura.Nested.Type.URITest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Estructura.Nested.Type.URI, as: TypeURI

  doctest Estructura.Nested.Type.URI

  describe "validation" do
    test "validates complete URIs" do
      valid_uris = [
        "https://example.com",
        "http://localhost:4000",
        "https://api.example.com/v1/users?id=123",
        "ftp://files.example.com/path/to/file.txt",
        "mailto:user@example.com",
        "ws://websocket.example.com"
      ]

      for uri_string <- valid_uris do
        uri = URI.parse(uri_string)
        assert {:ok, ^uri} = TypeURI.validate(uri)
      end
    end

    test "validates URI components" do
      uri = URI.parse("https://user:pass@example.com:8080/path?query=value#fragment")
      assert {:ok, uri} = TypeURI.validate(uri)
      assert uri.scheme == "https"
      assert uri.userinfo == "user:pass"
      assert uri.host == "example.com"
      assert uri.port == 8080
      assert uri.path == "/path"
      assert uri.query == "query=value"
      assert uri.fragment == "fragment"
    end

    test "rejects invalid URIs" do
      invalid_values = [
        "not a uri",
        123,
        %{},
        nil,
        "http://",
        "://invalid"
      ]

      for value <- invalid_values do
        assert {:error, _} = TypeURI.validate(value)
      end
    end
  end

  describe "coercion" do
    test "coerces string URIs" do
      valid_uris = [
        "https://example.com",
        "http://localhost:4000",
        "ftp://files.example.com"
      ]

      for uri_string <- valid_uris do
        assert {:ok, %URI{} = uri} = TypeURI.coerce(uri_string)
        assert URI.to_string(uri) == uri_string
      end
    end

    test "coerces URI structs" do
      uri = URI.parse("https://example.com")
      assert {:ok, ^uri} = TypeURI.coerce(uri)
    end

    test "handles invalid coercion inputs" do
      invalid_inputs = [
        123,
        %{},
        nil,
        ["not", "a", "uri"],
        ":::invalid:::"
      ]

      for input <- invalid_inputs do
        assert {:error, _} = TypeURI.coerce(input)
      end
    end
  end

  describe "generation" do
    property "generates valid URIs" do
      check all uri <- TypeURI.generate() do
        assert {:ok, uri} = TypeURI.validate(uri)
        assert is_binary(uri.scheme)
        assert is_binary(uri.host)
      end
    end

    property "generates URIs with specific schemes" do
      schemes = ["http", "https", "ftp"]

      check all uri <- TypeURI.generate(schemes: schemes) do
        assert uri.scheme in schemes
        assert {:ok, ^uri} = TypeURI.validate(uri)
      end
    end

    property "generates URIs with query parameters" do
      check all uri <- TypeURI.generate(with_query: true) do
        assert is_binary(uri.query) or is_nil(uri.query)
        assert {:ok, ^uri} = TypeURI.validate(uri)
      end
    end

    property "generates URIs with paths" do
      check all uri <- TypeURI.generate(with_path: true) do
        assert is_binary(uri.path)
        assert {:ok, ^uri} = TypeURI.validate(uri)
      end
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    describe "JSON encoding" do
      test "encodes URIs as strings" do
        uri_string = "https://example.com/path?query=value"
        uri = URI.parse(uri_string)
        assert Jason.encode!(uri) == "\"#{uri_string}\""
      end

      property "encoded URIs can be decoded back" do
        check all uri <- TypeURI.generate() do
          json = Jason.encode!(uri)
          {:ok, decoded} = TypeURI.coerce(Jason.decode!(json))
          assert URI.to_string(uri) == URI.to_string(decoded)
        end
      end
    end
  end

  describe "string representation" do
    property "converts to string and back" do
      check all uri <- TypeURI.generate() do
        str = URI.to_string(uri)
        assert {:ok, decoded} = TypeURI.coerce(str)
        assert URI.to_string(uri) == URI.to_string(decoded)
      end
    end

    test "handles all URI components in string conversion" do
      uri_string = "https://user:pass@example.com:8080/path?query=value#fragment"
      assert {:ok, uri} = TypeURI.coerce(uri_string)
      assert URI.to_string(uri) == uri_string
    end
  end
end
