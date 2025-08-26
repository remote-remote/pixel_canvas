defmodule PixelCanvas.PixelStore do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(:pixel_store, [:bag, :named_table, :protected])
    {:ok, %{}}
  end

  def store_pixels(pixels) do
    GenServer.cast(__MODULE__, {:store, pixels})
  end

  def get_pixels(region_x, region_y) do
    :ets.lookup(:pixel_store, {region_x, region_y})
    |> Enum.map(fn {_, {local_x, local_y}, color} ->
      %PixelCanvas.Pixel{
        opcode: 0,
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
    |> PixelCanvas.Pixel.encode_many()
  end

  def handle_cast({:store, pixels}, state) do
    Enum.each(pixels, fn pixel ->
      :ets.insert(
        :pixel_store,
        {{pixel.region_x, pixel.region_y}, {pixel.local_x, pixel.local_y}, pixel.color}
      )
    end)

    {:noreply, state}
  end
end
