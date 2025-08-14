defmodule PixelCanvas.Http.Router do
  alias PixelCanvas.Http.{Request, Response}

  def route(%Request{} = request) do
    route(
      request.method,
      String.split(request.full_path, "/") |> Enum.reject(&(&1 == "")),
      request
    )
  end

  def route(:GET, [], %Request{} = _request) do
    %Response{
      status_code: 200,
      status_message: "OK",
      body: "PixelCanvas Server"
    }
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
end
