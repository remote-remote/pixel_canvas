defmodule PixelCanvas.Pixel do
  defstruct [:ts, :region_x, :region_y, :local_x, :local_y, :opcode, :color]

  def parse_message(message) do
    for <<opcode::8, region_x::integer-10, region_y::integer-10, local_x::integer-10,
          local_y::integer-10, color::binary-2 <- message>> do
      %PixelCanvas.Pixel{
        opcode: opcode,
        region_x: region_x,
        region_y: region_y,
        local_x: local_x,
        local_y: local_y,
        color: color
      }
    end
  end

  def parse_server_message(message) do
    for <<ts::integer-64, opcode::8, region_x::integer-10, region_y::integer-10,
          local_x::integer-10, local_y::integer-10, color::binary-2 <- message>> do
      %PixelCanvas.Pixel{
        ts: ts,
        opcode: opcode,
        region_x: region_x,
        region_y: region_y,
        local_x: local_x,
        local_y: local_y,
        color: color
      }
    end
  end

  def encode_many(pixels) do
    pixels
    |> Enum.map(&encode_one/1)
    |> Enum.join()
  end

  def encode_one(%PixelCanvas.Pixel{} = pixel) do
    <<pixel.opcode::8, pixel.region_x::integer-10, pixel.region_y::integer-10,
      pixel.local_x::integer-10, pixel.local_y::integer-10, pixel.color::binary-2>>
  end
end
