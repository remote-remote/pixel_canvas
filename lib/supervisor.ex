defmodule PixelCanvas.Supervisor do
  use Supervisor

  # strategies:
  # :one_for_one - if a child process terminates, only that process is restarted.
  # :one_for_all - if a child process terminates, all other child processes are terminated and then all child processes (including the terminated one) are restarted.
  # :rest_for_one - if a child process terminates, the terminated child process and the rest of the children started after it, are terminated and restarted.

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {Infra.WebSocket.Broadcaster, []},
      {Infra.Telemetry,
       %{
         tcp_accepted: :counter,
         tcp_accept_latency: :histogram,
         tcp_rejected: :counter,
         ws_fragments_received: :counter,
         ws_frames_received: :counter,
         ws_messages_received: :counter,
         ws_fragment_frames_received: :counter,
         ws_broadcast_latency: :histogram,
         ws_outgoing_frame_size: :histogram,
         ws_messages_sent: :counter,
         ws_frames_sent: :counter,
         tcp_connections: :guage
       }},
      {DynamicSupervisor, name: Infra.ConnectionSupervisor},
      {Infra.TelemetryMonitor, []},
      {Infra.TcpListener,
       http_handler: {Infra.Http.Router, :route},
       websocket_handler: PixelCanvas.WebSocket.SocketHandler},
      {PixelCanvas.PixelBatcher, []},
      {PixelCanvas.PixelStore, []}
    ]

    # So the default strategy is :one_for_one, which we can override in each child spec
    Supervisor.init(children, strategy: :one_for_one)
  end
end
