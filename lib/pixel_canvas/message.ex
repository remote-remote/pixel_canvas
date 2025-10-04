defmodule PixelCanvas.Message do
  defstruct [:type, :data]

  @pixel 0
  @hello 1
  @metrics 2

  def parse_server_message(<<@pixel::integer-4, _rest::binary>> = message) do
    PixelCanvas.Pixel.parse_server_message(message)
  end
end
