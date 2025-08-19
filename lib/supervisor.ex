defmodule PixelCanvas.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: PixelCanvas.Http.ConnectionSupervisor},
      {PixelCanvas.Http.Server, [name: PixelCanvas.Http.Server]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
