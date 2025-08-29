defmodule PixelCanvas.WebSocket.SocketHandler do
  require Logger

  defmodule Point do
    defstruct [:region_x, :region_y, :local_x, :local_y, :opcode, :color]
  end

  def handle_message(message, state) do
    case message do
      <<_::binary-8, _rest::binary>> ->
        PixelCanvas.PixelBatcher.batch(message)

        message
        |> PixelCanvas.Pixel.parse_many()
        |> PixelCanvas.PixelStore.store_pixels()

        {:noreply, state}

      message ->
        IO.inspect(message, label: "Unknown message in socket handler")
        :ok
    end
  end

  def handle_connected(state) do
    {:reply, PixelCanvas.PixelStore.get_pixel_messages(0, 0), state}
  end
end
