defmodule Infra.Http.Request do
  require Logger

  defstruct version: nil,
            full_path: nil,
            method: nil,
            headers: %{},
            content_length: nil,
            body: nil,
            build_state: :empty

  def parse(data) do
    if !String.match?(data, ~r/\r\n\r\n/) do
      :fragment
    else
      [request, rest] = String.split(data, "\r\n\r\n", parts: 2)
      [start_line | headers] = String.split(request, "\r\n")

      [method, path, version] = String.split(start_line, " ")
      method = atomize_method(method)

      headers =
        Enum.into(headers, %{}, fn header ->
          [name, value] =
            String.split(header, ":", parts: 2)
            |> Enum.map(&String.trim(&1))

          {String.downcase(name), value}
        end)

      content_length =
        Map.get(headers, "content-length", "0")
        |> String.to_integer()

      if byte_size(rest) < content_length do
        :fragment
      else
        <<body::binary-size(content_length), rest::binary>> = rest

        request = %__MODULE__{
          method: method,
          full_path: path,
          version: version,
          headers: headers,
          body: body,
          content_length: content_length
        }

        Logger.debug("Parsed request: #{inspect(request)}")

        {request, rest}
      end
    end
  end

  defp atomize_method(method) do
    case method do
      "GET" -> :GET
      "POST" -> :POST
      "PUT" -> :PUT
      "DELETE" -> :DELETE
      "OPTIONS" -> :OPTIONS
      "HEAD" -> :HEAD
      "CONNECT" -> :CONNECT
      "TRACE" -> :TRACE
      "PATCH" -> :PATCH
    end
  end
end
