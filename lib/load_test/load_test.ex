defmodule Mix.Tasks.LoadTest do
  @connection_count 1024
  use Mix.Task
  require Logger
  alias PixelCanvas.PixelStore
  alias PixelCanvas.Pixel

  def run(args) do
    Mix.Task.run("app.start")
    :timer.sleep(1000)

    connections =
      for i <- 1..@connection_count do
        {:ok, conn} = TestConnection.start_link(i)
        conn
      end
  end

  # defp generate_pixel do
  #   <<opcode::8, region_x::integer-10, region_y::integer-10, local_x::integer-10,
  #     local_y::integer-10, color::binary-2>>
  # end
end
