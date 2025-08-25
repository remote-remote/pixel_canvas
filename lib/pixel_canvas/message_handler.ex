defmodule PixelCanvas.WebSocket.MessageHandler do
  require Logger

  defmodule Point do
    defstruct [:region_x, :region_y, :local_x, :local_y, :opcode, :color]
  end

  def handle_message(message, state) do
    case message do
      <<opcode::8, region_x::integer-10, region_y::integer-10, local_x::integer-10,
        local_y::integer-10, color::binary-2>> ->
        point = %Point{
          opcode: opcode,
          region_x: region_x,
          region_y: region_y,
          local_x: local_x,
          local_y: local_y,
          color: color
        }

        Logger.info(point)

        {:broadcast, message, state}

      _ ->
        :ok
    end
  end
end
