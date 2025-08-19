defmodule PixelCanvas do
  use Application

  @moduledoc """
  Documentation for `PixelCanvas`.
  """

  @impl true
  def start(_type, _args) do
    PixelCanvas.Supervisor.start_link(name: PixelCanvas.Supervisor)
  end
end
