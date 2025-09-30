defmodule Infra.WebSocket.Connection do
  use GenServer
  alias Infra.WebSocket.Frame
  require Logger

  defstruct [:socket, :message_buffer, :state, :handler]

  def start_link(%{socket: _, handler: _} = state, opts \\ []) do
    Logger.info("Starting websocket connection")
    GenServer.start_link(__MODULE__, state, opts)
  end

  # Client API
  defp handle_frame(%Frame{fin: 1} = frame, state) do
    Infra.Telemetry.record(:ws_messages_received, 1)
    full_message = state.message_buffer <> frame.payload
    state = Map.put(state, :message_buffer, <<>>)

    case apply(state.handler, :handle_message, [full_message, Map.get(state, :state)]) do
      {:reply, message, new_state} ->
        send_message(state.socket, message)
        {:ok, Map.put(state, :state, new_state)}

      {:broadcast, message, new_state} ->
        Infra.WebSocket.Broadcaster.broadcast(message)
        {:ok, Map.put(state, :state, new_state)}

      {:noreply, new_state} ->
        {:ok, Map.put(state, :state, new_state)}

      :ok ->
        {:ok, state}
    end
  end

  defp handle_frame(%Frame{fin: 0} = frame, state) do
    Infra.Telemetry.record(:ws_fragment_frames_received, 1)

    {:ok,
     Map.update!(state, :message_buffer, fn buffer ->
       buffer <> frame.payload
     end)}
  end

  def send_message(socket, msg) do
    Frame.construct(msg)
    |> Enum.each(fn frame ->
      :gen_tcp.send(socket, frame)
      Infra.Telemetry.record(:ws_outgoing_frame_size, byte_size(frame))
      Infra.Telemetry.record(:ws_frames_sent, 1)
    end)

    Infra.Telemetry.record(:ws_messages_sent, 1)
  end

  # Server API
  def init(%{socket: socket, handler: handler}) do
    {:ok,
     %__MODULE__{
       socket: socket,
       handler: handler,
       message_buffer: <<>>,
       state: %{}
     }, {:continue, :connected}}
  end

  def handle_continue(:connected, state) do
    case apply(state.handler, :handle_connected, [state]) do
      {:reply, message, new_state} ->
        send_message(state.socket, message)
        {:noreply, Map.put(state, :state, new_state)}

      {:noreply, new_state} ->
        {:noreply, Map.put(state, :state, new_state)}
    end
  end

  def handle_info({:broadcast_message, message}, state) do
    send_message(state.socket, message)
    {:noreply, state}
  end

  def handle_cast({:frame, frame}, state) do
    handle_frame(frame, state)
    {:noreply, state}
  end
end
