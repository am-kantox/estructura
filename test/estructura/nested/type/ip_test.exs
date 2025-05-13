defmodule Estructura.Nested.Type.IPTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Estructura.Nested.Type.IP

  doctest Estructura.Nested.Type.IP

  describe "IPv4 validation" do
    test "validates common IPv4 addresses" do
      valid_ips = [
        "127.0.0.1",
        "192.168.1.1",
        "10.0.0.0",
        "172.16.0.1",
        "255.255.255.255"
      ]

      for ip_string <- valid_ips do
        {:ok, ip} = IP.coerce(ip_string)
        assert {:ok, ip} = IP.validate(ip)
        assert ip.type == :v4
      end
    end

    test "validates IPv4 address ranges" do
      for n1 <- [0, 127, 255],
          n2 <- [0, 128, 255],
          n3 <- [0, 128, 255],
          n4 <- [0, 128, 255] do
        ip = %IP{type: :v4, n1: n1, n2: n2, n3: n3, n4: n4}
        assert {:ok, ^ip} = IP.validate(ip)
      end
    end

    test "rejects invalid IPv4 values" do
      invalid_ips = [
        %IP{type: :v4, n1: 256, n2: 1, n3: 1, n4: 1},
        %IP{type: :v4, n1: -1, n2: 1, n3: 1, n4: 1},
        %IP{type: :v4, n1: 1, n2: 1, n3: 1, n4: 256},
        "256.1.1.1",
        "1.2.3.4.5",
        "invalid"
      ]

      for ip <- invalid_ips do
        assert {:error, _} = IP.validate(ip)
      end
    end
  end

  describe "IPv6 validation" do
    test "validates common IPv6 addresses" do
      valid_ips = [
        "::1",
        "2001:db8::1",
        "fe80::1",
        "2001:db8:85a3:8d3:1319:8a2e:370:7348"
      ]

      for ip_string <- valid_ips do
        {:ok, ip} = IP.coerce(ip_string)
        assert {:ok, ip} = IP.validate(ip)
        assert ip.type == :v6
      end
    end

    test "validates IPv6 address ranges" do
      for n1 <- [0, 32_768, 65_535],
          n2 <- [0, 32_768, 65_535] do
        ip = %IP{
          type: :v6,
          n1: n1,
          n2: n2,
          n3: 0,
          n4: 0,
          n5: 0,
          n6: 0,
          n7: 0,
          n8: 1
        }

        assert {:ok, ^ip} = IP.validate(ip)
      end
    end

    test "rejects invalid IPv6 values" do
      invalid_ips = [
        %IP{type: :v6, n1: 65_536, n2: 1, n3: 1, n4: 1, n5: 1, n6: 1, n7: 1, n8: 1},
        %IP{type: :v6, n1: -1, n2: 1, n3: 1, n4: 1, n5: 1, n6: 1, n7: 1, n8: 1},
        # double ::
        "2001:db8::1::1",
        "gggg::",
        "invalid"
      ]

      for ip <- invalid_ips do
        assert {:error, _} = IP.validate(ip)
      end
    end
  end

  describe "coercion" do
    test "coerces string IPv4 addresses" do
      ip_string = "192.168.1.1"
      assert {:ok, ip} = IP.coerce(ip_string)
      assert ip.type == :v4
      assert ip.n1 == 192
      assert ip.n2 == 168
      assert ip.n3 == 1
      assert ip.n4 == 1
    end

    test "coerces string IPv6 addresses" do
      ip_string = "2001:db8::1"
      assert {:ok, ip} = IP.coerce(ip_string)
      assert ip.type == :v6
      assert ip.n1 == 0x2001
      assert ip.n2 == 0xDB8
      assert ip.n8 == 1
    end

    test "coerces tuples" do
      assert {:ok, ip4} = IP.coerce({192, 168, 1, 1})
      assert ip4.type == :v4
      assert ip4.n1 == 192

      assert {:ok, ip6} = IP.coerce({0x2001, 0xDB8, 0, 0, 0, 0, 0, 1})
      assert ip6.type == :v6
      assert ip6.n1 == 0x2001
    end

    test "handles invalid coercion inputs" do
      invalid_inputs = [
        "not an ip",
        123,
        # wrong tuple size
        {1, 2, 3},
        # invalid value
        {1, 2, 3, 256},
        nil
      ]

      for input <- invalid_inputs do
        assert {:error, _} = IP.coerce(input)
      end
    end
  end

  describe "generation" do
    property "generates valid IPs" do
      check all ip <- IP.generate() do
        assert {:ok, ip} = IP.validate(ip)
        assert ip.type in [:v4, :v6]
      end
    end

    property "generates IPv4 addresses" do
      check all ip <- IP.generate(version: :v4) do
        assert {:ok, ip} = IP.validate(ip)
        assert ip.type == :v4
        assert ip.n1 in 0..255
        assert ip.n2 in 0..255
        assert ip.n3 in 0..255
        assert ip.n4 in 0..255
      end
    end

    property "generates IPv6 addresses" do
      check all ip <- IP.generate(version: :v6) do
        assert {:ok, ip} = IP.validate(ip)
        assert ip.type == :v6
        assert ip.n1 in 0..65_535
        assert ip.n2 in 0..65_535
      end
    end
  end

  describe "coerces IP in shape" do
    test "top-level" do
      import IP, only: [sigil_IP: 2]

      assert {:ok, %Estructura.IP{ip: ~IP[192.168.1.0]}} =
               Estructura.IP.cast(%{ip: "192.168.1.0"})
    end
  end

  describe "string representation" do
    property "converts to string and back" do
      check all ip <- IP.generate() do
        str = to_string(ip)
        assert {:ok, decoded} = IP.coerce(str)
        assert to_string(ip) == to_string(decoded)
      end
    end

    test "formats IPv4 addresses correctly" do
      ip = %IP{type: :v4, n1: 192, n2: 168, n3: 1, n4: 1}
      assert to_string(ip) == "192.168.1.1"
    end

    test "formats IPv6 addresses correctly" do
      # Regular IPv6
      ip1 = %IP{type: :v6, n1: 0x2001, n2: 0xDB8, n3: 0, n4: 0, n5: 0, n6: 0, n7: 0, n8: 1}
      assert to_string(ip1) == "2001:db8::1"

      # Loopback
      ip2 = %IP{type: :v6, n1: 0, n2: 0, n3: 0, n4: 0, n5: 0, n6: 0, n7: 0, n8: 1}
      assert to_string(ip2) == "::1"
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    describe "JSON encoding" do
      test "encodes IPs as strings" do
        ip4 = %IP{type: :v4, n1: 192, n2: 168, n3: 1, n4: 1}
        assert Jason.encode!(ip4) == "\"192.168.1.1\""

        ip6 = %IP{type: :v6, n1: 0x2001, n2: 0xDB8, n3: 0, n4: 0, n5: 0, n6: 0, n7: 0, n8: 1}
        assert Jason.encode!(ip6) == "\"2001:db8::1\""
      end

      property "encoded IPs can be decoded back" do
        check all ip <- IP.generate() do
          json = Jason.encode!(ip)
          {:ok, decoded} = IP.coerce(Jason.decode!(json))
          assert to_string(ip) == to_string(decoded)
        end
      end
    end
  end
end
