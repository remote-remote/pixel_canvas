defmodule Infra.WebSocket.Connection do
  use GenServer
  alias Infra.WebSocket.Frame
  require Logger

  defstruct [:socket, :message_buffer, :state, :handler]

  # Client API
  def start_link(%{socket: _, handler: _} = state, opts \\ []) do
    Logger.info("Starting websocket connection")
    GenServer.start_link(__MODULE__, state, opts)
  end

  def send_message(socket, msg, type \\ :binary) do
    Frame.construct(msg, type)
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
    apply(state.handler, :handle_connected, [state])
    |> handle_handler_response(state)
  end

  def handle_info({:broadcast_message, message}, state) do
    send_message(state.socket, message)
    {:noreply, state}
  end

  def handle_info({:broadcast_message, message, type}, state) do
    send_message(state.socket, message, type)
    {:noreply, state}
  end

  def handle_cast({:frame, frame}, state) do
    handle_frame(frame, state)
  end

  # Private helpers
  defp handle_frame(%Frame{fin: 1} = frame, %{message_buffer: <<>>} = state) do
    Infra.Telemetry.record(:ws_messages_received, 1)

    apply(state.handler, :handle_message, [frame.payload, Map.get(state, :state)])
    |> handle_handler_response(state)
  end

  defp handle_frame(%Frame{fin: 1} = frame, state) do
    Infra.Telemetry.record(:ws_messages_received, 1)
    full_message = state.message_buffer <> frame.payload
    state = Map.put(state, :message_buffer, <<>>)

    apply(state.handler, :handle_message, [full_message, Map.get(state, :state)])
    |> handle_handler_response(state)
  end

  defp handle_frame(%Frame{fin: 0} = frame, state) do
    Infra.Telemetry.record(:ws_fragment_frames_received, 1)

    {:noreply,
     Map.update!(state, :message_buffer, fn buffer ->
       buffer <> frame.payload
     end)}
  end

  defp handle_handler_response(response, state) do
    case response do
      {:reply, [_ | _] = messages, new_state} ->
        for message <- messages do
          send_message(state.socket, message)
        end

        {:noreply, Map.put(state, :state, new_state)}

      {:reply, [], new_state} ->
        {:noreply, Map.put(state, :state, new_state)}

      {:reply, message, new_state} ->
        send_message(state.socket, message)
        {:noreply, Map.put(state, :state, new_state)}

      {:noreply, new_state} ->
        {:noreply, Map.put(state, :state, new_state)}

      :ok ->
        {:noreply, state}
    end
  end
end
