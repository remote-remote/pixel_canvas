defmodule PixelCanvas.Http.Router do
  alias PixelCanvas.Http.{Request, Response}
  alias PixelCanvas.WebSocket

  def route(%Request{} = request) do
    route(
      request.method,
      String.split(request.full_path, "/") |> Enum.reject(&(&1 == "")),
      request
    )
  end

  def route(:GET, ["ws"], %Request{} = request) do
    WebSocket.Handshake.handle_upgrade(request)
  end

  def route(:GET, [], %Request{} = _request) do
    case File.read("./assets/index.html") do
      {:ok, file} ->
        %Response{
          status_code: 200,
          status_message: "OK",
          body: file,
          headers: %{
            "Content-Type" => "text/html"
          }
        }

      {:error, _reason} ->
        %Response{
          status_code: 404,
          status_message: "Not found",
          body: "Not Found"
        }
    end
  end

  def route(:GET, ["assets" | asset_path], %Request{} = _request) do
    path = Path.join(["./assets" | asset_path])

    case File.read(path) do
      {:ok, file} ->
        %Response{
          status_code: 200,
          status_message: "OK",
          body: file,
          headers: %{
            "Content-Type" => get_content_type(asset_path)
          }
        }

      {:error, :enoent} ->
        %Response{
          status_code: 404,
          status_message: "Not found",
          body: "Not Found"
        }

      {:error, _} ->
        %Response{
          status_code: 500,
          status_message: "Internal Server Error",
          body: "Internal Server Error"
        }
    end
  end

  def route(:POST, ["api", "pixels"], %Request{} = _request) do
    %Response{
      status_code: 200,
      status_message: "OK",
      body: "Pixels Received",
      headers: %{"Content-Type" => "application/json"}
    }
  end

  def route(_method, _path, _request) do
    %Response{
      status_code: 404,
      status_message: "Not Found",
      body: "Not Found"
    }
  end

  defp get_content_type(path) do
    case Path.extname(path) do
      ".js" -> "application/javascript"
      ".html" -> "text/html"
      ".css" -> "text/css"
      ".webp" -> "image/webp"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      _ -> "text/any"
    end
  end
end
