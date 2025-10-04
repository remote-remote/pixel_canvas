defmodule PixelCanvas.Pixel do
  @pixel 0
  defstruct [:user_id, :region_x, :region_y, :local_x, :local_y, :opcode, :color]

  def parse_client_message(message, user_id) do
    for <<opcode::8, region_x::integer-10, region_y::integer-10, local_x::integer-10,
          local_y::integer-10, color::binary-2 <- message>> do
      %PixelCanvas.Pixel{
        user_id: user_id,
        opcode: opcode,
        region_x: region_x,
        region_y: region_y,
        local_x: local_x,
        local_y: local_y,
        color: color
      }
    end
  end

  def parse_server_message(<<@pixel::integer-4, message::binary>>) do
    <<region_x::integer-10, region_y::integer-10, blocks::binary>> =
      message

    message_header = %{
      region_x: region_x,
      region_y: region_y
    }

    parse_blocks(blocks, message_header) |> List.flatten()
  end

  defp parse_blocks(blocks, message_header, acc \\ [])

  defp parse_blocks(<<>>, _, acc) do
    Enum.reverse(acc)
  end

  defp parse_blocks(blocks, message_header, acc) do
    <<user_id::integer-20, num_pixels::integer-20, rest::binary>> = blocks
    <<pixel_data::binary-size(num_pixels * 5), blocks::binary>> = rest

    block_header = %{
      user_id: user_id,
      num_pixels: num_pixels
    }

    pixels = parse_pixel_block(pixel_data, message_header, block_header)
    parse_blocks(blocks, [pixels | acc])
  end

  defp parse_pixel_block(pixels, message_header, block_header) do
    for <<opcode::integer-4, local_x::integer-10, local_y::integer-10, color::binary-2>> <- pixels do
      %PixelCanvas.Pixel{
        user_id: block_header.user_id,
        opcode: opcode,
        region_x: message_header.region_x,
        region_y: message_header.region_y,
        local_x: local_x,
        local_y: local_y,
        color: color
      }
    end
  end

  def encode_client_pixel(pixel) do
    <<pixel.opcode::8, pixel.region_x::integer-10, pixel.region_y::integer-10,
      pixel.local_x::integer-10, pixel.local_y::integer-10, pixel.color::binary-2>>
  end

  def encode_server_pixels(pixels) do
    pixels
    |> Enum.group_by(fn pixel -> {pixel.region_x, pixel.region_y} end)
    |> Enum.map(fn {{region_x, region_y}, pixels} ->
      region_blocks =
        pixels
        |> Enum.group_by(& &1.user_id)
        |> Enum.map(fn {user_id, user_pixels} ->
          pixel_block =
            user_pixels
            |> Enum.map(fn pixel ->
              <<pixel.opcode::4, pixel.local_x::integer-10, pixel.local_y::integer-10,
                pixel.color::binary-2>>
            end)
            |> Enum.join()

          <<user_id::integer-20, length(user_pixels)::integer-20, pixel_block::binary>>
        end)
        |> Enum.join()

      <<@pixel::integer-4, region_x::integer-10, region_y::integer-10, region_blocks::binary>>
    end)
  end
end
