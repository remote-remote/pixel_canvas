defmodule PixelCanvas.PixelBatcher do
  use GenServer
  require Logger
  @refresh_rate_ms 17

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    timer = Process.send_after(self(), :flush, @refresh_rate_ms)

    {:ok,
     %{
       messages: <<>>,
       timer: timer,
       last_flush: DateTime.utc_now(),
       last_interval: 0
     }}
  end

  def batch(message) do
    GenServer.cast(__MODULE__, {:batch, message})
  end

  def log_state() do
    GenServer.cast(__MODULE__, :log_state)
  end

  def handle_info(:flush, state) do
    if byte_size(state.messages) > 0 do
      GenServer.cast(Infra.WebSocket.Broadcaster, {:broadcast, state.messages})
    end

    Process.cancel_timer(state.timer)
    timer = Process.send_after(self(), :flush, @refresh_rate_ms)

    last_interval = DateTime.diff(DateTime.utc_now(), state.last_flush, :millisecond)

    {:noreply,
     %{
       state
       | messages: <<>>,
         timer: timer,
         last_flush: DateTime.utc_now(),
         last_interval: last_interval
     }}
  end

  def handle_cast(:log_state, state) do
    Logger.info("PixelBatcher state: #{inspect(state)}")
    {:noreply, state}
  end

  def handle_cast({:batch, message}, state) do
    {:noreply, Map.update!(state, :messages, fn messages -> messages <> message end)}
  end

  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
end
