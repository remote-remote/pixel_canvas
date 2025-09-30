defmodule Infra.TelemetryMonitor do
  use GenServer
  require Logger
  alias Infra.Telemetry

  def start_link(_opts) do
    GenServer.start_link(
      __MODULE__,
      %{
        last_flush: nil
      },
      name: __MODULE__
    )
  end

  def init(state) do
    :timer.send_interval(1000, self(), :gather_stats)
    {:ok, state}
  end

  def handle_info(:gather_stats, state) do
    connections = DynamicSupervisor.count_children(Infra.ConnectionSupervisor)
    Telemetry.record(:tcp_connections, connections.active)
    {:noreply, state}
  end
end
