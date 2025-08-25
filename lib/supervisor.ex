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
      {DynamicSupervisor, name: Infra.ConnectionSupervisor},
      {Infra.TcpListener, name: Infra.TcpListener}
    ]

    # So the default strategy is :one_for_one, which we can override in each child spec
    Supervisor.init(children, strategy: :one_for_one)
  end
end
