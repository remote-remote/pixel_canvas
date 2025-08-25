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
    Logger.info("Starting Listener")
    port = Keyword.get(opts, :port, 3000)

    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, active: false, packet: :raw, reuseaddr: true])

    # TODO: move this configuration out to the application config
    accept_loop(
      socket,
      {Infra.Http.Router, :route},
      {PixelCanvas.WebSocket.MessageHandler, :handle_message}
    )
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
