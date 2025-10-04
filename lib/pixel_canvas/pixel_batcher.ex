defmodule PixelCanvas.PixelBatcher do
  use GenServer
  require Logger
  alias PixelCanvas.Pixel
  @refresh_rate_ms 17

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    timer = :timer.send_interval(@refresh_rate_ms, self(), :flush)

    {:ok,
     %{
       pixels: [],
       timer: timer
     }}
  end

  def batch(pixels) do
    GenServer.cast(__MODULE__, {:batch, pixels})
  end

  def handle_info(:flush, state) do
    if length(state.pixels) > 0 do
      Pixel.encode_server_pixels(state.pixels)
      |> Enum.each(fn message ->
        Infra.WebSocket.Broadcaster.broadcast(message)
      end)
    end

    {:noreply,
     %{
       state
       | pixels: []
     }}
  end

  def handle_cast({:batch, pixel}, state) do
    {:noreply, %{state | pixels: state.pixels ++ pixel}}
  end
end
