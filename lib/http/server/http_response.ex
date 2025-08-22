defmodule PixelCanvas.Http.Response do
  alias PixelCanvas.Http.Request
  require Logger

  defstruct version: "HTTP/1.1",
            status_code: 200,
            status_message: "OK",
            headers: %{},
            body: ""

  # maybe this should be more specific
  def prepare(%__MODULE__{status_code: 101} = response, _request) do
    response
  end

  def prepare(%__MODULE__{} = response, %Request{} = request) do
    body = response.body || ""

    Map.update!(response, :headers, &Map.merge(&1, get_encoding_headers(request.headers)))
    |> Map.put(:body, body)
    |> Map.update!(:headers, fn headers ->
      Map.put(headers, "Content-Length", byte_size(body))
      |> Map.put_new("Content-Type", "text/plain")
    end)
  end

  defp get_encoding_headers(headers) do
    # ["gzip"]
    supported_encodings = []

    with encodings when is_list(encodings) <- get_encoding_header(headers),
         [encoding | _] <- Enum.filter(encodings, &(&1 in supported_encodings)) do
      %{"Content-Encoding" => encoding}
    else
      _ -> %{}
    end
  end

  defp get_encoding_header(headers) do
    Map.get(headers, "Accept-Encoding", "")
    |> String.split(",")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.trim/1)
  end

  def to_binary(%__MODULE__{} = response) do
    headers =
      Enum.map(response.headers, fn {name, value} ->
        "#{name}: #{value}"
      end)
      |> Enum.join("\r\n")

    serialized =
      "#{response.version} #{response.status_code} #{response.status_message}\r\n" <>
        headers <> "\r\n\r\n"

    case response.body do
      "" ->
        serialized <> ""

      nil ->
        serialized <> ""

      _ ->
        serialized <> "#{response.body}"
    end
  end
end
