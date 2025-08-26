defmodule PixelCanvas.PixelBatcher do
  use GenServer
  @refresh_rate_ms 17

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    timer = Process.send_after(self(), :flush, @refresh_rate_ms)

    {:ok,
     %{
       messages: <<>>,
       timer: timer
     }}
  end

  def batch(message) do
    GenServer.cast(__MODULE__, {:batch, message})
  end

  def handle_info(:flush, state) do
    if byte_size(state.messages) > 0 do
      GenServer.cast(Infra.WebSocket.Broadcaster, {:broadcast, state.messages})
    end

    Process.cancel_timer(state.timer)
    timer = Process.send_after(self(), :flush, @refresh_rate_ms)

    {:noreply, Map.put(state, :messages, <<>>) |> Map.put(:timer, timer)}
  end

  def handle_cast({:batch, message}, state) do
    {:noreply, Map.update!(state, :messages, fn messages -> messages <> message end)}
  end

  def handle_call(:get_messages, _from, state) do
    {:reply, state.messages, state}
  end
end
