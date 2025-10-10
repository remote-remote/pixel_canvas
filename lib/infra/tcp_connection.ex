defmodule Infra.TcpConnection do
  use GenServer, restart: :temporary
  require Logger
  alias Infra.Http.{Request, Response}
  alias Infra.WebSocket.Frame

  defstruct [
    :conn,
    :state,
    :protocol,
    :listener,
    :buffer,
    :http_handler,
    :websocket_handler,
    :websocket_connection
  ]

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(%{
        http_handler: http_handler,
        websocket_handler: websocket_handler
      }) do
    {:ok,
     %__MODULE__{
       conn: nil,
       protocol: :http,
       buffer: <<>>,
       http_handler: http_handler,
       websocket_handler: websocket_handler,
       state: %{}
     }}
  end

  def handle_call({:set_socket, socket}, _from, state) do
    :inet.setopts(socket, active: :once)
    {:reply, :ok, %{state | conn: socket}}
  end

  def handle_info({:tcp, socket, data}, state) do
    resp =
      case state.protocol do
        :http ->
          handle_http(data, state)

        :websocket ->
          handle_websocket(data, state)
      end

    :inet.setopts(socket, active: :once)

    resp
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.debug("Closing connection")
    :gen_tcp.close(state.conn)
    if state.websocket_connection, do: GenServer.stop(state.websocket_connection, :normal)
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("Error receiving data: #{inspect(reason)}")
    :gen_tcp.close(state.conn)
    {:stop, :normal, state}
  end

  def handle_cast(
        {:handle_packet, data},
        %__MODULE__{} = state
      ) do
    case state.protocol do
      :http ->
        handle_http(data, state)

      :websocket ->
        handle_websocket(data, state)
    end
  end

  def handle_websocket(data, state) do
    case Frame.parse(state.buffer <> data) do
      :fragment ->
        Infra.Telemetry.record(:ws_fragments_received, 1)
        {:reply, :fragment, Map.put(state, :buffer, data)}

      {%Frame{} = frame, rest} ->
        state = Map.put(state, :buffer, <<>>)

        Infra.Telemetry.record(:ws_frames_received, 1)
        GenServer.cast(state.websocket_connection, {:frame, frame})

        if byte_size(rest) > 0 do
          handle_websocket(rest, state)
        else
          {:noreply, state}
        end
    end
  end

  def handle_http(data, state) do
    case Request.parse(state.buffer <> data) do
      :fragment ->
        {:noreply, Map.put(state, :buffer, state.buffer <> data)}

      {%Request{} = request, rest} ->
        # TODO: Handle errors
        {handler_module, handler_function} = state.http_handler

        # CAN this be done in a Task?
        response = apply(handler_module, handler_function, [request])

        :gen_tcp.send(
          state.conn,
          response
          |> Response.prepare(request)
          |> Response.to_binary()
        )

        state = Map.put(state, :buffer, <<>>)

        if is_websocket_upgrade?(response) do
          {:ok, ws} =
            Infra.WebSocket.Connection.start_link(%{
              socket: state.conn,
              handler: state.websocket_handler
            })

          Infra.WebSocket.Broadcaster.register(ws, state.conn)

          state =
            Map.put(state, :protocol, :websocket)
            |> Map.put(:websocket_connection, ws)

          {:noreply, Map.put(state, :protocol, :websocket)}
        else
          # TODO: What if we have rest data but no keep-alive?
          if byte_size(rest) > 0 do
            handle_http(rest, state)
          else
            if !keep_alive?(request) do
              :gen_tcp.close(state.conn)
              {:stop, :normal, state}
            else
              {:noreply, state}
            end
          end
        end

        # {:http_error, reason} ->
        #   Logger.error("Error parsing request: #{inspect(reason)}")
        #
        #   %Response{
        #     status_code: 400,
        #     status_message: "Bad Request"
        #   }
        #
        # {:error, error} ->
        #   Logger.error("Error parsing request: #{inspect(error)}")
        #
        #   %Response{
        #     status_code: 500,
        #     status_message: "Internal Server Error"
        #   }
    end
  end

  defp is_websocket_upgrade?(%Response{status_code: 101, headers: %{"Upgrade" => "websocket"}}),
    do: true

  defp is_websocket_upgrade?(%Response{}), do: false

  defp keep_alive?(%Request{headers: %{"connection" => "keep-alive"}}), do: true
  defp keep_alive?(%Request{headers: %{}}), do: false
end
