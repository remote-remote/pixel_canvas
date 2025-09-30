defmodule Infra.Telemetry do
  @ttl 60_000 * 60
  @flush_interval 1000
  @bucket_size 1_000

  use Agent
  require Logger

  # ets format: {{bucket_timestamp, metric_name}, value}
  # metric format: {type, bucket_size}

  def start_link(metrics \\ %{}) do
    GenServer.start_link(__MODULE__, metrics, name: __MODULE__)
  end

  def init(metrics) do
    :ets.new(:telemetry, [:ordered_set, :named_table, :protected])
    :ets.new(:histogram_buffer, [:duplicate_bag, :named_table, :protected])

    # TODO: clean these up on shutdown
    flush_timer = :timer.send_interval(@flush_interval, self(), :flush)
    histo_timer = :timer.send_interval(@bucket_size, self(), :aggregate_histograms)

    {:ok,
     %{metrics: metrics, last_flush: nil, flush_timer: flush_timer, histo_timer: histo_timer}}
  end

  def handle_info(:flush, state) do
    cutoff =
      (DateTime.utc_now()
       |> DateTime.to_unix(:second)) - @ttl

    :ets.select_delete(:telemetry, [
      {{{:"$1", :"$2"}, :"$3"}, [{:<, :"$1", cutoff}], [true]}
    ])

    {:noreply, %{state | last_flush: DateTime.utc_now()}}
  end

  def handle_info(:aggregate_histograms, state) do
    current_seconds = :os.system_time(:second)
    bucket = current_seconds - 1

    raw_data = :ets.match(:histogram_buffer, {{bucket, :"$1"}, :"$2"})

    Enum.reduce(raw_data, %{}, fn [name, value], acc ->
      Map.update(
        acc,
        name,
        %{
          count: 1,
          sum: value,
          min: value,
          max: value
        },
        fn existing ->
          %{
            count: existing.count + 1,
            sum: existing.sum + value,
            min: min(existing.min, value),
            max: max(existing.max, value)
          }
        end
      )
    end)
    |> Enum.each(fn {name, value} ->
      :ets.insert(:telemetry, {{bucket, name}, value})
    end)

    :ets.match_delete(:histogram_buffer, {{bucket, :"$1"}, :"$2"})

    {:noreply, state}
  end

  def handle_cast({:record, metric, value, ts}, state) do
    metric_type = Map.get(state.metrics, metric, [])
    record_metric(ts, metric, metric_type, value)
    {:noreply, state}
  end

  def handle_call({:get_metrics, metric}, _from, state) do
    metrics = :ets.match(:telemetry, {{:"$1", metric}, :"$2"})
    {:reply, metrics, state}
  end

  def get_metrics(metric) do
    GenServer.call(__MODULE__, {:get_metrics, metric})
  end

  def record(metric, value) do
    ts = DateTime.utc_now() |> DateTime.to_unix(:second)
    GenServer.cast(__MODULE__, {:record, metric, value, ts})
  end

  defp record_metric(bucket, name, :counter, value) do
    :ets.update_counter(:telemetry, {bucket, name}, {2, value}, {{bucket, name}, 0})
  end

  defp record_metric(bucket, name, :guage, value) do
    :ets.insert(:telemetry, {{bucket, name}, value})
  end

  defp record_metric(bucket, name, :histogram, value) do
    :ets.insert(:histogram_buffer, {{bucket, name}, value})
  end
end
