defmodule PixelCanvas.PixelStore do
  use GenServer
  require Logger

  # TODO: this doesn't need to be a GenServer, it's just an ets table.

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(:pixel_store, [:set, :named_table, :protected])
    {:ok, %{}}
  end

  def store_pixels(pixels) do
    GenServer.cast(__MODULE__, {:store, pixels})
  end

  def get_pixels(region_x, region_y) do
    :ets.match(:pixel_store, {{region_x, region_y, :"$1", :"$2"}, :"$3", :"$4"})
    |> Enum.map(fn [local_x, local_y, user_id, color] ->
      %PixelCanvas.Pixel{
        opcode: 1,
        user_id: user_id,
        region_x: region_x,
        region_y: region_y,
        local_x: local_x,
        local_y: local_y,
        color: color
      }
    end)
  end

  def get_pixel_messages(region_x, region_y) do
    get_pixels(region_x, region_y)
    |> PixelCanvas.Pixel.encode_server_pixels()
  end

  def handle_cast({:store, pixels}, state) do
    :ets.insert(:pixel_store, pixels)

    {:noreply, state}
  end
end
