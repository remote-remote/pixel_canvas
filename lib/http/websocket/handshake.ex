defmodule PixelCanvas.WebSocket.Handshake do
  alias PixelCanvas.Http.Response
  require Logger

  def handle_upgrade(%PixelCanvas.Http.Request{} = request) do
    with :ok <- validate_headers(request.headers),
         {:ok, accept_key} <- generate_accept_key(request.headers["Sec-WebSocket-Key"]) do
      %PixelCanvas.Http.Response{
        status_code: 101,
        status_message: "Switching Protocols",
        headers: %{
          "Connection" => "Upgrade",
          "Upgrade" => "websocket",
          "Sec-WebSocket-Accept" => accept_key
        }
      }
    else
      {:error, reason} ->
        %PixelCanvas.Http.Response{
          status_code: 400,
          status_message: "Bad Request",
          body: "#{inspect(reason)}"
        }
    end
  end

  def generate_accept_key(client_key) do
    case validate_key(client_key) do
      {:ok, client_key} ->
        accept_key =
          :crypto.hash(:sha, client_key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
          |> Base.encode64()

        {:ok, accept_key}

      {:error, _reason} ->
        {:error, :invalid_key}
    end
  end

  def validate_headers(headers) when is_map(headers) do
    headers =
      Enum.map(headers, fn {k, v} ->
        {String.downcase(k), v}
      end)
      |> Enum.into(%{})

    with {:connection, "Upgrade"} <- {:connection, Map.get(headers, "connection")},
         {:upgrade, "websocket"} <- {:upgrade, Map.get(headers, "upgrade")},
         {:sec_websocket_version, "13"} <-
           {:sec_websocket_version, Map.get(headers, "sec-websocket-version")},
         {:sec_websocket_key, client_key} when is_binary(client_key) <-
           {:sec_websocket_key, Map.get(headers, "sec-websocket-key")} do
      :ok
    else
      {:connection, nil} ->
        {:error, :missing_connection_header}

      {:connection, _} ->
        {:error, :invalid_connection_header}

      {:upgrade, nil} ->
        {:error, :missing_upgrade_header}

      {:upgrade, _} ->
        {:error, :invalid_upgrade_header}

      {:sec_websocket_version, nil} ->
        {:error, :missing_websocket_version_header}

      {:sec_websocket_version, _} ->
        {:error, :unsupported_version}

      {:sec_websocket_key, nil} ->
        {:error, :missing_websocket_key}

      {:sec_websocket_key, _} ->
        {:error, :invalid_websocket_key}
    end
  end

  def validate_headers(_headers), do: {:error, :invalid_headers}

  def build_response(client_key) do
    accept_key = generate_accept_key(client_key)

    %Response{
      status_code: 101,
      status_message: "Switching Protocols",
      headers: %{
        "Connection" => "Upgrade",
        "Upgrade" => "websocket",
        "Sec-WebSocket-Accept" => accept_key
      }
    }
  end

  defp validate_key(client_key) when is_binary(client_key) do
    # I'm not sure if this is the correct size
    with size when size >= 10 and size < 25 <- byte_size(client_key),
         {:ok, _decoded_key} <- Base.decode64(client_key) do
      {:ok, client_key}
    else
      :error ->
        Logger.debug("Not base 64: #{inspect(client_key)}")
        {:error, :not_base64_encoded}

      _ ->
        Logger.debug("Wrong size: #{inspect(client_key)}")
        {:error, :wrong_size}
    end
  end

  defp validate_key(_client_key), do: {:error, :invalid_key}
end
