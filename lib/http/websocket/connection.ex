defmodule PixelCanvas.WebSocket.Connection do
  defmacro __using__(_opts) do
    quote do
      use GenServer
      @behaviour PixelCanvas.WebSocket.Connection
      import PixelCanvas.WebSocket.Connection
      alias PixelCanvas.WebSocket.Frame
      require Logger

      # Provide default start_link that users can override
      def start_link(socket, state, opts \\ []) do
        GenServer.start_link(__MODULE__, %{socket: socket, state: state}, opts)
      end

      defoverridable start_link: 2

      # Server API
      def init(%{socket: socket, state: state}) do
        {:ok, listener} = Task.start_link(__MODULE__, :listen_loop, [socket, self()])

        {:ok,
         %{
           socket: socket,
           message_buffer: <<>>,
           frame_buffer: <<>>,
           listener: listener,
           state: state
         }}
      end

      def handle_call({:handle_recv, data}, _from, state) do
        handle_data(state.frame_buffer <> data, state)
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

      defp handle_frame(%Frame{fin: 1} = frame, state) do
        full_message = state.message_buffer <> frame.payload
        state = Map.put(state, :message_buffer, <<>>)
        Logger.info("Completed a message: #{inspect(full_message)}")

        case handle_message(full_message, Map.get(state, :state)) do
          {:reply, message, new_state} ->
            send_message(state.socket, message)
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

      def send_message(socket, msg) do
        Frame.construct(msg)
        |> Enum.each(fn frame ->
          :gen_tcp.send(socket, frame)
        end)
      end
    end
  end

  @callback handle_message(payload :: binary(), connection :: map()) ::
              :ok | {:reply, binary(), map()} | {:error, reason :: term()}
end
