defmodule Infra.WebSocket.Broadcaster do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def register(pid, socket) do
    GenServer.call(__MODULE__, {:register, pid, socket})
  end

  def unregister(pid) do
    GenServer.call(__MODULE__, {:unregister, pid})
  end

  def broadcast(message, type \\ :binary) do
    GenServer.cast(__MODULE__, {:broadcast, message, type})
  end

  def handle_call({:register, pid, socket}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, Map.put(state, pid, socket)}
  end

  def handle_call({:unregister, pid}, _from, state) do
    {:reply, :ok, Map.delete(state, pid)}
  end

  def handle_cast({:broadcast, message, type}, state) do
    start_time = :os.system_time(:millisecond)
    frames = Infra.WebSocket.Frame.construct(message, type)

    Infra.Telemetry.record(:ws_messages_sent, 1)

    for {_pid, socket} <- state do
      frames
      |> Enum.each(fn frame ->
        :gen_tcp.send(socket, frame)
        Infra.Telemetry.record(:ws_outgoing_frame_size, byte_size(frame))
        Infra.Telemetry.record(:ws_frames_sent, 1)
      end)
    end

    end_time = :os.system_time(:millisecond)
    Infra.Telemetry.record(:ws_broadcast_latency, end_time - start_time)

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    IO.puts("Down")
    {:noreply, Map.delete(state, pid)}
  end
end
