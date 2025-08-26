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
        conn: conn,
        http_handler: http_handler,
        websocket_handler: websocket_handler
      }) do
    {:ok, listener} = Task.start_link(__MODULE__, :recv_loop, [conn, self()])

    {:ok,
     %__MODULE__{
       conn: conn,
       protocol: :http,
       buffer: <<>>,
       http_handler: http_handler,
       websocket_handler: websocket_handler,
       state: %{},
       listener: listener
     }}
  end

  def recv_loop(socket, handler) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        GenServer.cast(handler, {:handle_packet, data})
        recv_loop(socket, handler)

      {:error, :closed} ->
        GenServer.cast(handler, :connection_closed)

      {:error, reason} ->
        Logger.error("Error receiving data: #{inspect(reason)}")
        GenServer.cast(handler, {:receive_error, reason})
    end
  end

  def handle_websocket(data, state) do
    case Frame.parse(data) do
      :fragment ->
        {:reply, :fragment, Map.put(state, :buffer, data)}

      {%Frame{} = frame, rest} ->
        state = Map.put(state, :buffer, <<>>)

        GenServer.cast(state.websocket_connection, {:frame, frame})

        if byte_size(rest) > 0 do
          handle_websocket(rest, state)
        else
          {:noreply, state}
        end
    end
  end

  def handle_http(data, state) do
    case Request.parse(data) do
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

          Infra.WebSocket.Broadcaster.register(ws)

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

  def handle_cast({:receive_error, reason}, state) do
    Logger.error("Error receiving data: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_cast(:connection_closed, state) do
    Logger.debug("Closing connection")
    {:stop, :normal, state}
  end

  defp is_websocket_upgrade?(%Response{status_code: 101, headers: %{"Upgrade" => "websocket"}}),
    do: true

  defp is_websocket_upgrade?(%Response{}), do: false

  defp keep_alive?(%Request{headers: %{"connection" => "keep-alive"}}), do: true
  defp keep_alive?(%Request{headers: %{}}), do: false
end
