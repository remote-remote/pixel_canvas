defmodule PixelCanvas.Pixel do
  defstruct [:region_x, :region_y, :local_x, :local_y, :opcode, :color]

  def parse_many(message) do
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

  def parse_one(
        <<opcode::8, region_x::integer-10, region_y::integer-10, local_x::integer-10,
          local_y::integer-10, color::binary-2>>
      ) do
    %PixelCanvas.Pixel{
      opcode: opcode,
      region_x: region_x,
      region_y: region_y,
      local_x: local_x,
      local_y: local_y,
      color: color
    }
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
