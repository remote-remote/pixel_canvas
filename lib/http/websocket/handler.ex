defmodule PixelCanvas.WebSocket.Handler do
  use GenServer
  require Logger
  alias PixelCanvas.WebSocket.Frame

  def start_link(socket, opts \\ []) do
    GenServer.start_link(__MODULE__, socket, opts)
  end

  # This runs outside of the Handler process in its own task
  # and passes messages to the Handler
  def listen_loop(socket, handler) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        GenServer.call(handler, {:handle_recv, data})
        listen_loop(socket, handler)

      {:error, :closed} ->
        raise "Connection closed"

      {:error, reason} ->
        Logger.error("Error receiving data: #{inspect(reason)}")
        raise "Unknown data receive error"
    end
  end

  # Server API
  def init(socket) do
    {:ok, listener} = Task.start_link(__MODULE__, :listen_loop, [socket, self()])

    {:ok,
     %{
       socket: socket,
       message_buffer: <<>>,
       frame_buffer: <<>>,
       listener: listener
     }}
  end

  def handle_call({:handle_recv, data}, _from, state) do
    handle_data(state.frame_buffer <> data, state)
  end

  defp handle_data(data, state) do
    case Frame.parse(data) do
      :fragment ->
        IO.puts("got fragment, noreplying")
        {:reply, :fragment, Map.put(state, :frame_buffer, data)}

      {%Frame{} = frame, <<>>} ->
        IO.puts("frame and empty rest, handling frame")
        state = Map.put(state, :frame_buffer, <<>>)

        {:ok, new_state} = handle_frame(frame, state)
        {:reply, :handled, new_state}

      {%Frame{} = frame, rest} ->
        IO.puts("frame and non-empty rest, handling frame and recursing")
        state = Map.put(state, :frame_buffer, <<>>)

        case handle_frame(frame, state) do
          {:ok, new_state} ->
            handle_data(rest, new_state)

          {:error, reason} ->
            Logger.info("Error handling frame: #{inspect(reason)}")
            handle_data(rest, state)
        end

      _ ->
        {:reply, :unknown, state}
    end
  end

  defp handle_frame(%Frame{fin: 0} = frame, state) do
    {:ok,
     Map.update!(state, :message_buffer, fn buffer ->
       buffer <> frame.payload
     end)}
  end

  defp handle_frame(%Frame{fin: 1} = frame, state) do
    full_message = state.message_buffer <> frame.payload
    Logger.info("Completed a message: #{inspect(full_message)}")
    send_message("Hello from server", state)

    {:ok, Map.put(state, :message_buffer, <<>>)}
  end

  defp handle_frame(%Frame{} = frame, state) do
    IO.puts("We got some unmatching frame: #{inspect(frame)}")
    {:ok, state}
  end

  def send_message(msg, %{socket: socket}) do
    :gen_tcp.send(socket, Frame.construct(msg))
  end
end
