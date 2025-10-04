defmodule Infra.TcpListener do
  alias Infra.TcpConnection
  require Logger

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_listening, [opts]},
      restart: :permanent
    }
  end

  def start_listening(opts) do
    {:ok, pid} =
      Task.start_link(__MODULE__, :setup_and_accept, [
        opts
      ])

    {:ok, pid}
  end

  def setup_and_accept(opts) do
    port = Keyword.get(opts, :port, 3000)
    Logger.info("Starting Listener")

    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, active: false, packet: :raw, reuseaddr: true, backlog: 4096])

    accept_loop(socket, opts[:http_handler], opts[:websocket_handler])
  end

  def accept_loop(listen_socket, http_handler, websocket_handler) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        Infra.Telemetry.record(:tcp_accepted, 1)
        start = DateTime.utc_now()

        {:ok, pid} =
          DynamicSupervisor.start_child(
            Infra.ConnectionSupervisor,
            {TcpConnection,
             %{
               http_handler: http_handler,
               websocket_handler: websocket_handler
             }}
          )

        :ok = :gen_tcp.controlling_process(client_socket, pid)
        GenServer.call(pid, {:set_socket, client_socket})

        time = DateTime.diff(DateTime.utc_now(), start, :millisecond)
        Infra.Telemetry.record(:tcp_accept_latency, time)

        accept_loop(listen_socket, http_handler, websocket_handler)

      {:error, _reason} ->
        Infra.Telemetry.record(:tcp_rejected, 1)
        accept_loop(listen_socket, http_handler, websocket_handler)
    end
  end
end
