defmodule Infra.WebSocket.Connection do
  use GenServer
  alias Infra.WebSocket.Frame
  require Logger

  defstruct [:socket, :message_buffer, :state, :handler]

  # Provide default start_link that users can override
  def start_link(%{socket: _, handler: _} = state, opts \\ []) do
    Logger.info("Starting websocket connection")
    GenServer.start_link(__MODULE__, state, opts)
  end

  # Server API
  def init(%{socket: socket, handler: handler}) do
    {:ok,
     %__MODULE__{
       socket: socket,
       handler: handler,
       message_buffer: <<>>,
       state: %{}
     }}
  end

  def handle_info({:broadcast_message, message}, state) do
    send_message(state.socket, message)
    {:noreply, state}
  end

  def handle_cast({:frame, frame}, state) do
    handle_frame(frame, state)
    {:noreply, state}
  end

  defp handle_frame(%Frame{fin: 1} = frame, state) do
    full_message = state.message_buffer <> frame.payload
    state = Map.put(state, :message_buffer, <<>>)

    {handler_module, handler_function} = state.handler

    case apply(handler_module, handler_function, [full_message, Map.get(state, :state)]) do
      {:reply, message, new_state} ->
        Logger.info("Sending message: #{inspect(message)}")
        send_message(state.socket, message)
        {:ok, Map.put(state, :state, new_state)}

      {:broadcast, message, new_state} ->
        Infra.WebSocket.Broadcaster.broadcast(message)
        {:ok, Map.put(state, :state, new_state)}

      :ok ->
        {:ok, state}
    end
  end

  defp handle_frame(%Frame{fin: 0} = frame, state) do
    {:ok,
     Map.update!(state, :message_buffer, fn buffer ->
       buffer <> frame.payload
     end)}
  end

  def send_message(socket, msg) do
    Frame.construct(msg)
    |> Enum.each(fn frame ->
      :gen_tcp.send(socket, frame)
    end)
  end
end
