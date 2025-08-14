defmodule PixelCanvas.Http.Request do
  require Logger

  defstruct full_path: nil, headers: %{}, body: nil, method: nil

  def parse(client) do
    with {:ok, start_line} <- :gen_tcp.recv(client, 0),
         {:http_request, method, {:abs_path, full_path}, _} <- start_line,
         {:ok, headers} <- get_headers(client),
         _ <- :inet.setopts(client, packet: :raw),
         {:ok, body} <-
           get_body(client, Map.get(headers, "Content-Length", "0") |> String.to_integer()) do
      Logger.info("#{inspect(method)} #{inspect(full_path)}")

      {:ok,
       %__MODULE__{
         method: method,
         full_path: full_path,
         headers: headers,
         body: body
       }}
    end
  end

  defp get_headers(client, headers \\ %{}) do
    case :gen_tcp.recv(client, 0) do
      {:ok, {:http_header, _, _atom_name, string_name, value}} ->
        get_headers(client, Map.put(headers, string_name, value))

      {:ok, :http_eoh} ->
        {:ok, headers}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_body(client, length) do
    case length do
      0 ->
        {:ok, ""}

      _ ->
        case :gen_tcp.recv(client, length) do
          {:ok, body_line} ->
            Logger.debug("getting body line: #{inspect(body_line)}")
            {:ok, body_line}

          {:error, error} ->
            error |> inspect() |> Logger.error()
            {:error, error}
        end
    end
  end
end
