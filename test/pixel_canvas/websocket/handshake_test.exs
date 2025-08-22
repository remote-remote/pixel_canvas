defmodule PixelCanvas.WebSocket.HandshakeTest do
  use ExUnit.Case
  alias PixelCanvas.Http.{Response, Request}
  alias PixelCanvas.WebSocket

  # Note: This test file covers the WebSocket handshake implementation
  # that will be built as part of Phase 2 of the project.
  # 
  # These tests follow TDD principles - they define the expected behavior
  # before implementation, helping guide the development process.

  describe "WebSocket handshake key generation" do
    test "generates correct Sec-WebSocket-Accept from client key" do
      # Test case from RFC 6455 example
      client_key = "dGhlIHNhbXBsZSBub25jZQ=="
      expected_accept = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="

      # This function will be implemented in WebSocket.Handshake module
      assert WebSocket.Handshake.generate_accept_key(client_key) == {:ok, expected_accept}
    end

    test "generates different accept keys for different client keys" do
      key1 = "x3JJHMbDL1EzLkh9GBhXDw=="
      key2 = "dGhlIHNhbXBsZSBub25jZQ=="

      {:ok, accept1} = WebSocket.Handshake.generate_accept_key(key1)
      {:ok, accept2} = WebSocket.Handshake.generate_accept_key(key2)

      assert accept1 != accept2
      assert is_binary(accept1)
      assert is_binary(accept2)
    end

    test "returns error for invalid client key format" do
      invalid_keys = [
        "",
        "too_short",
        "not_base64_encoded!",
        nil
      ]

      for invalid_key <- invalid_keys do
        assert {:error, :invalid_key} = WebSocket.Handshake.generate_accept_key(invalid_key)
      end
    end
  end

  describe "handshake request validation" do
    test "validates required WebSocket headers" do
      valid_headers = %{
        "connection" => "Upgrade",
        "upgrade" => "websocket",
        "sec-websocket-version" => "13",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert :ok = WebSocket.Handshake.validate_headers(valid_headers)
    end

    test "rejects request missing Connection header" do
      headers = %{
        "upgrade" => "websocket",
        "sec-websocket-version" => "13",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert {:error, :missing_connection_header} = WebSocket.Handshake.validate_headers(headers)
    end

    test "rejects request with wrong Connection value" do
      headers = %{
        "connection" => "keep-alive",
        "upgrade" => "websocket",
        "sec-websocket-version" => "13",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert {:error, :invalid_connection_header} = WebSocket.Handshake.validate_headers(headers)
    end

    test "rejects request missing Upgrade header" do
      headers = %{
        "connection" => "Upgrade",
        "sec-websocket-version" => "13",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert {:error, :missing_upgrade_header} = WebSocket.Handshake.validate_headers(headers)
    end

    test "rejects request with wrong Upgrade value" do
      headers = %{
        "connection" => "Upgrade",
        "upgrade" => "h2c",
        "sec-websocket-version" => "13",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert {:error, :invalid_upgrade_header} = WebSocket.Handshake.validate_headers(headers)
    end

    test "rejects unsupported WebSocket version" do
      headers = %{
        "connection" => "Upgrade",
        "upgrade" => "websocket",
        # Old version
        "sec-websocket-version" => "8",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert {:error, :unsupported_version} = WebSocket.Handshake.validate_headers(headers)
    end

    test "rejects request missing WebSocket key" do
      headers = %{
        "connection" => "Upgrade",
        "upgrade" => "websocket",
        "sec-websocket-version" => "13"
      }

      assert {:error, :missing_websocket_key} = WebSocket.Handshake.validate_headers(headers)
    end

    test "handles case insensitive header names" do
      headers = %{
        "Connection" => "Upgrade",
        "UPGRADE" => "websocket",
        "Sec-WebSocket-Version" => "13",
        "SEC-WEBSOCKET-KEY" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      assert :ok = WebSocket.Handshake.validate_headers(headers)
    end
  end

  describe "handshake response generation" do
    test "generates complete handshake response" do
      client_key = "x3JJHMbDL1EzLkh9GBhXDw=="

      response = WebSocket.Handshake.build_response(client_key)

      expected_accept_key = WebSocket.Handshake.generate_accept_key(client_key)

      # Expected response structure:
      expected_response = %Response{
        status_code: 101,
        status_message: "Switching Protocols",
        headers: %{
          "Connection" => "Upgrade",
          "Upgrade" => "websocket",
          "Sec-WebSocket-Accept" => expected_accept_key
        }
      }

      assert response == expected_response
    end
  end

  describe "integration tests" do
    test "complete handshake flow with valid request" do
      # Simulate receiving a WebSocket upgrade request

      request = %Request{
        method: "GET",
        full_path: "/ws",
        headers: %{
          "Host" => "localhost:8080",
          "Upgrade" => "websocket",
          "Connection" => "Upgrade",
          "Sec-WebSocket-Key" => "x3JJHMbDL1EzLkh9GBhXDw==",
          "Sec-WebSocket-Version" => "13"
        }
      }

      # Expected workflow (to be implemented):
      response = WebSocket.Handshake.handle_upgrade(request)
      assert response.status_code == 101
      assert response.status_message == "Switching Protocols"
    end

    test "rejects invalid handshake attempts" do
      invalid_requests = [
        # Missing WebSocket headers
        """
        GET /ws HTTP/1.1\r
        Host: localhost:8080\r
        \r
        """,

        # Wrong method
        """
        POST /ws HTTP/1.1\r
        Host: localhost:8080\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
        Sec-WebSocket-Version: 13\r
        \r
        """,

        # Wrong version
        """
        GET /ws HTTP/1.1\r
        Host: localhost:8080\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
        Sec-WebSocket-Version: 8\r
        \r
        """
      ]

      for invalid_request <- invalid_requests do
        # {:ok, http_request} = HTTP.Request.parse(invalid_request)
        # assert {:error, _reason} = WebSocket.Handshake.handle_upgrade(http_request)
      end
    end
  end

  describe "edge cases and security" do
    for {reason, key} <- [
          {"not base 64", "not-base64!"},
          {"too short", "too_short"},
          {"empty string", ""},
          {"16 characters", "exactly_16_chars_"},
          {"too long", String.duplicate("a", 100)},
          {"nil", nil}
        ] do
      test "handles malformed WebSocket key: #{reason}" do
        assert {:error, _} = WebSocket.Handshake.generate_accept_key(unquote(key))
      end
    end

    test "handles case variations in header values" do
      header_variations = [
        {"connection", "upgrade"},
        {"connection", "Upgrade"},
        {"connection", "UPGRADE"},
        {"upgrade", "websocket"},
        {"upgrade", "WebSocket"},
        {"upgrade", "WEBSOCKET"}
      ]

      base_headers = %{
        "connection" => "Upgrade",
        "upgrade" => "websocket",
        "sec-websocket-version" => "13",
        "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
      }

      for {header, value} <- header_variations do
        headers = Map.put(base_headers, header, value)
        assert :ok = WebSocket.Handshake.validate_headers(headers)
      end
    end

    test "prevents header injection attacks" do
      # Test headers with CRLF injection attempts
      malicious_values = [
        "websocket\r\nX-Injected: malicious",
        "websocket\nSet-Cookie: evil=true",
        "Upgrade\r\n\r\nHTTP/1.1 200 OK"
      ]

      for malicious_value <- malicious_values do
        headers = %{
          "connection" => "Upgrade",
          "upgrade" => malicious_value,
          "sec-websocket-version" => "13",
          "sec-websocket-key" => "x3JJHMbDL1EzLkh9GBhXDw=="
        }

        # Should reject malicious headers
        assert {:error, _} = WebSocket.Handshake.validate_headers(headers)
      end
    end
  end

  # Helper functions for test data generation
  defp generate_random_websocket_key do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp build_websocket_request(path \\ "/ws", headers \\ %{}) do
    default_headers = %{
      "host" => "localhost:8080",
      "upgrade" => "websocket",
      "connection" => "Upgrade",
      "sec-websocket-key" => generate_random_websocket_key(),
      "sec-websocket-version" => "13"
    }

    final_headers = Map.merge(default_headers, headers)

    header_lines =
      final_headers
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
      |> Enum.join("\r\n")

    "GET #{path} HTTP/1.1\r\n#{header_lines}\r\n\r\n"
  end
end

