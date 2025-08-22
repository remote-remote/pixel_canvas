defmodule PixelCanvas.Http.Server do
  alias PixelCanvas.Http.ConnectionHandler
  require Logger
  use GenServer

  def start_link(opts \\ []) do
    Logger.info("Starting server")
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    port = Keyword.get(opts, :port, 3000)

    case :gen_tcp.listen(port, [:binary, active: false, packet: :http_bin, reuseaddr: true]) do
      {:ok, socket} ->
        {:ok, accept_loop} =
          Task.start_link(__MODULE__, :accept_loop, [socket, self()])

        {:ok,
         %{
           started_at: DateTime.utc_now(),
           port: port,
           socket: socket,
           accept_loop: accept_loop,
           refs: %{},
           connections: %{}
         }}

      {:error, reason} ->
        Logger.error("Failed to start server: #{inspect(reason)}")
        # This exits the task, which might cause app to exit
        raise "Listen failed: #{inspect(reason)}"
    end
  end

  def accept_loop(socket, server) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        Logger.info("Accepted connection from #{inspect(client)}")
        GenServer.cast(server, {:accept, client})
        accept_loop(socket, server)

      {:error, :closed} ->
        Logger.info("Socket closed, stopping accept loop")
        :ok

      {:error, reason} ->
        Logger.error("Error accepting connection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_call(:get_connection_count, _from, state) do
    {:reply, Kernel.map_size(state.refs), state}
  end

  def handle_call(:get_status, _from, state) do
    reply = %{
      port: state.port,
      socket: state.socket,
      connections: Kernel.map_size(state.refs),
      started_at: state.started_at
    }

    {:reply, reply, state}
  end

  def handle_cast({:accept, client}, state) do
    Logger.debug("Accepted connection from #{inspect(client)}")

    {:ok, connection_pid} =
      DynamicSupervisor.start_child(
        PixelCanvas.Http.ConnectionSupervisor,
        {ConnectionHandler, client}
      )

    ref = Process.monitor(connection_pid)
    state = %{state | refs: Map.put(state.refs, ref, connection_pid)}

    {:noreply, state}
  end

  def handle_cast(:crash_me, _state) do
    raise "Crash me"
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    Logger.info("Connection #{inspect(pid)} closed")
    state = %{state | refs: Map.delete(state.refs, ref)}
    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.info("Received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  def terminate(:normal, state) do
    Logger.info("Server terminated normally")

    DynamicSupervisor.stop(PixelCanvas.Http.ConnectionSupervisor, :normal)

    :gen_tcp.close(state.socket)
    :ok
  end

  def terminate({error, _trace}, state) do
    Logger.info("Server terminated with error: #{inspect(error)}")

    DynamicSupervisor.stop(PixelCanvas.Http.ConnectionSupervisor, :normal)

    :gen_tcp.close(state.socket)
    :ok
  end
end
