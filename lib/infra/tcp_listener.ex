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
      :gen_tcp.listen(port, [:binary, active: false, packet: :raw, reuseaddr: true])

    accept_loop(socket, opts[:http_handler], opts[:websocket_handler])
  end

  def accept_loop(listen_socket, http_handler, websocket_handler) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)
    Logger.info("Accepted socket: #{inspect(client_socket)}")

    DynamicSupervisor.start_child(
      Infra.ConnectionSupervisor,
      {TcpConnection,
       %{
         conn: client_socket,
         http_handler: http_handler,
         websocket_handler: websocket_handler
       }}
    )

    accept_loop(listen_socket, http_handler, websocket_handler)
  end
end
