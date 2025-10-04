defmodule PixelCanvas.WebSocket.SocketHandler do
  require Logger

  defmodule Point do
    defstruct [:region_x, :region_y, :local_x, :local_y, :opcode, :color]
  end

  def handle_message(message, state) do
    case message do
      <<_::binary-8, _rest::binary>> ->
        pixels = PixelCanvas.Pixel.parse_client_message(message, state.user_id)
        PixelCanvas.PixelBatcher.batch(pixels)
        PixelCanvas.PixelStore.store_pixels(pixels)

        {:noreply, state}

      message ->
        IO.inspect(message, label: "Unknown message in socket handler")
        :ok
    end
  end

  def handle_connected(state) do
    pixels = PixelCanvas.PixelStore.get_pixel_messages(0, 0)
    # TODO: figure out how to get a unique user id for each connection
    user_id = :rand.uniform(1000)
    hello_message = <<1::4, user_id::20, 0::integer-8>>
    {:reply, [hello_message | pixels], Map.put(state, :user_id, user_id)}
  end
end
