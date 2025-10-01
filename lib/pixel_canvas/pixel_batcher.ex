defmodule PixelCanvas.PixelBatcher do
  use GenServer
  require Logger
  alias PixelCanvas.Pixel
  @refresh_rate_ms 17

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    timer = Process.send_after(self(), :flush, @refresh_rate_ms)

    {:ok,
     %{
       pixels: [],
       timer: timer,
       last_flush: DateTime.utc_now(),
       last_interval: 0
     }}
  end

  def batch(message, user_id) do
    GenServer.cast(__MODULE__, {:batch, message, user_id})
  end

  def handle_info(:flush, state) do
    if length(state.pixels) > 0 do
      Pixel.encode_many(state.pixels)
      |> Enum.each(fn message ->
        GenServer.cast(Infra.WebSocket.Broadcaster, {:broadcast, message})
      end)
    end

    Process.cancel_timer(state.timer)
    timer = Process.send_after(self(), :flush, @refresh_rate_ms)
    last_interval = DateTime.diff(DateTime.utc_now(), state.last_flush, :millisecond)

    {:noreply,
     %{
       state
       | pixels: [],
         timer: timer,
         last_flush: DateTime.utc_now(),
         last_interval: last_interval
     }}
  end

  def handle_cast({:batch, message, user_id}, state) do
    {:noreply, %{state | pixels: state.pixels ++ Pixel.parse_message(message, user_id)}}
  end
end
