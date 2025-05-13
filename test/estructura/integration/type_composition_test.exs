defmodule Estructura.Integration.TypeCompositionTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Estructura.Nested.Type
  import Estructura.Nested.Type.IP, only: [sigil_IP: 2]

  alias Estructura.Server

  describe "type composition" do
    @tag skip: "Implement `Nested.validate/1`"
    test "creates and validates a complex structure" do
      _server = %Server{
        name: "web-1",
        ip: ~IP[192.168.1.1],
        status: :online,
        uri: URI.parse("https://example.com"),
        last_check: DateTime.utc_now(),
        tags: [:critical, :warning],
        services: %{
          http: %{port: 80, status: :online},
          https: %{port: 443, status: :online}
        }
      }

      # assert {:ok, ^server} = Server.validate(server)
    end

    @tag skip: "Implement `Nested.validate/1`"
    test "validates nested service statuses" do
      _invalid_server = %Server{
        services: %{
          http: %{port: 80, status: :invalid_status}
        }
      }

      # assert {:error, _} = Server.validate(invalid_server)
    end

    test "coerces individual fields" do
      raw_data = %{
        "name" => "web-1",
        "ip" => "192.168.1.1",
        "status" => "online",
        "uri" => "https://example.com",
        "last_check" => "2024-01-01T10:00:00Z",
        "tags" => ["critical", "warning"],
        "services" => %{
          "http" => %{"port" => 80, "status" => "online"},
          "https" => %{"port" => 443, "status" => "online"}
        }
      }

      assert {:ok, server} = Server.cast(raw_data)
      assert server.ip.type == :v4
      assert server.ip.n1 == 192
      assert server.status == :online
      assert server.uri.scheme == "https"
      assert server.tags == [:critical, :warning]
    end

    property "generates valid structures" do
      check all server <- Server.__generator__() do
        # assert {:ok, ^server} = Server.validate(server)
        assert is_binary(server.name)
        assert match?({:ok, _}, Type.IP.validate(server.ip))
        assert server.status in [:online, :offline, :maintenance]
        assert match?({:ok, _}, Type.URI.validate(server.uri))
        assert match?({:ok, _}, Type.DateTime.validate(server.last_check))
        assert Enum.all?(server.tags, &(&1 in [:critical, :warning, :info]))
      end
    end
  end

  describe "JSON encoding" do
    test "encodes complex structure to JSON" do
      server = %Server{
        name: "web-1",
        ip: ~IP[192.168.1.1],
        status: :online,
        uri: URI.parse("https://example.com"),
        last_check: ~U[2024-01-01 10:00:00Z],
        tags: [:critical],
        services: %{
          http: %{port: 80, status: :online}
        }
      }

      json = Jason.encode!(server)
      assert {:ok, decoded} = Server.cast(Jason.decode!(json))
      assert decoded.name == server.name
      assert to_string(decoded.ip) == to_string(server.ip)
      assert decoded.status == server.status
      assert decoded.uri.host == server.uri.host
      assert DateTime.compare(decoded.last_check, server.last_check) == :eq
      assert decoded.tags == server.tags
      # assert decoded.services.http.status == server.services.http.status
    end
  end

  describe "flattening" do
    @tag :skip
    test "flattens complex structure" do
      server = %Server{
        name: "web-1",
        ip: ~IP[192.168.1.1],
        status: :online,
        uri: URI.parse("https://example.com"),
        last_check: ~U[2024-01-01 10:00:00Z],
        tags: [:critical],
        services: %{
          http: %{port: 80, status: :online}
        }
      }

      flattened = Estructura.Flattenable.flatten(server)
      assert flattened["name"] == "web-1"
      assert flattened["ip"] == ~IP[192.168.1.1]
      assert flattened["status"] == :online
      assert flattened["uri"] == "https://example.com"
      assert flattened["tags_0"] == "critical"
      assert flattened["services_http_status"] == "online"
    end
  end

  describe "transformation" do
    test "transforms complex structure" do
      server = %Server{
        name: "web-1",
        ip: ~IP[192.168.1.1],
        status: :online,
        uri: URI.parse("https://example.com"),
        last_check: ~U[2024-01-01 10:00:00Z],
        tags: [:critical],
        services: %{
          http: %{port: 80, status: :online}
        }
      }

      transformed = Estructura.Transformer.transform(server)
      assert is_list(transformed)
      assert Keyword.get(transformed, :name) == "web-1"
      assert Keyword.get(transformed, :ip) == "192.168.1.1"
      assert Keyword.get(transformed, :status) == :online
    end
  end
end
