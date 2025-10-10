defmodule Infra.TelemetryReporter do
  use GenServer
  require Logger
  alias Infra.Telemetry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :timer.send_interval(1000, self(), :broadcast_metrics)

    {:ok,
     %{
       last_query: :os.system_time(:second)
     }}
  end

  def handle_info(:broadcast_metrics, state) do
    next_query = :os.system_time(:second)

    [
      :tcp_connections,
      :ws_messages_received,
      :ws_messages_sent,
      :ws_outgoing_frame_size,
      :ws_broadcast_latency
    ]
    |> Enum.map(fn metric ->
      Telemetry.get_metrics(metric, state.last_query, next_query)
      |> build_message(metric)
      |> Infra.WebSocket.Broadcaster.broadcast(:text)
    end)

    {:noreply, %{state | last_query: next_query}}
  end

  defp build_message({type, timeseries}, metric) do
    """
    {
    "type": "metrics",
    "metricType": "#{Atom.to_string(type)}",
    "name": "#{Atom.to_string(metric)}",
    "timeseries": [
    #{timeseries |> Enum.map(fn [ts, value] -> """
      {
        "timestamp": #{ts},
        "value": #{extract_value(type, value)}
      }
      """ end) |> Enum.join(",")}
    ]
    }
    """
  end

  defp extract_value(:counter, type), do: type
  defp extract_value(:guage, type), do: type

  defp extract_value(:histogram, value) do
    """
    {
      "count": #{value.count},
      "sum": #{value.sum},
      "min": #{value.min},
      "max": #{value.max}
    }
    """
  end
end
