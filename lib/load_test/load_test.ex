defmodule Mix.Tasks.LoadTest do
  @connection_count 1000
  use Mix.Task
  require Logger
  alias PixelCanvas.PixelStore
  alias PixelCanvas.Pixel

  def run(args) do
    count = Enum.at(args, 0, "1000") |> String.to_integer()
    Mix.Task.run("app.start")
    :timer.sleep(100)
    TestStats.start_link()

    for i <- 1..count do
      {:ok, conn} = TestConnection.start_link(i)
      conn
    end
  end
end
