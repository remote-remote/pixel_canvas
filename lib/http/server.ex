defmodule PixelCanvas.Http.Server do
  use GenServer
  require Logger
  alias PixelCanvas.Http.{Request, Response, Router}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_connection_count(pid) do
    GenServer.call(pid, :get_connection_count)
  end

  def accept_loop(socket, server_pid) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("Accepted connection from #{inspect(client)}")
    GenServer.call(server_pid, :new_connection)
    Task.start_link(__MODULE__, :handle_request, [client, server_pid])

    accept_loop(socket, server_pid)
  end

  def handle_request(conn, server_pid) do
    response =
      case Request.parse(conn) do
        {:ok, %Request{} = request} ->
          Router.route(request)
          |> Response.prepare(request)

        {:http_error, reason} ->
          Logger.error("Error parsing request: #{inspect(reason)}")

          %Response{
            status_code: 400,
            status_message: "Bad Request"
          }

        {:error, :closed} ->
          Logger.error("Connection closed")
          {:error, :closed}

        {:error, error} ->
          Logger.error("Error parsing request: #{inspect(error)}")

          %Response{
            status_code: 500,
            status_message: "Internal Server Error"
          }
      end

    case response do
      %Response{} = response ->
        :gen_tcp.send(conn, Response.to_binary(response))
        :gen_tcp.close(conn)

      {:error, :closed} ->
        Logger.error("Connection already closed")

      _ ->
        Logger.error("Unknown parsing error: #{inspect(response)}")
    end

    GenServer.call(server_pid, :close_connection)
  end

  # GenServer callbacks
  def init(opts) do
    port = Keyword.get(opts, :port)

    case :gen_tcp.listen(port, [:binary, active: false, packet: :http_bin, reuseaddr: true]) do
      {:ok, socket} ->
        Logger.info("Started listening on #{port}")
        {:ok, accept_loop} = Task.start_link(__MODULE__, :accept_loop, [socket, self()])

        {:ok,
         %{
           socket: socket,
           accept_loop: accept_loop,
           port: port,
           connections: 0
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_call(:new_connection, _from, state) do
    {:reply, state, Map.update!(state, :connections, &(&1 + 1))}
  end

  def handle_call(:close_connection, _from, state) do
    {:reply, state, Map.update!(state, :connections, &(&1 - 1))}
  end

  def handle_call(:get_connection_count, _from, state) do
    {:reply, state.connections, state}
  end
end
