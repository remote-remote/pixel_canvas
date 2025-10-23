defmodule Infra.Telemetry do
  # 5 minutes
  @ttl 60_000
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
    :ets.new(:telemetry, [:ordered_set, :named_table, :public])
    :ets.new(:histogram_buffer, [:duplicate_bag, :named_table, :public])
    :ets.new(:metric_types, [:set, :named_table, :public])

    Enum.each(metrics, fn {metric, type} ->
      :ets.insert(:metric_types, {metric, type})
    end)

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

  def handle_call(
        {:get_metrics, metric, start_ts, end_ts},
        _from,
        state
      )
      when is_integer(start_ts) and is_integer(end_ts) do
    metrics =
      case :ets.lookup(:metric_types, metric) do
        [] ->
          Logger.error("Unknown metric: #{metric}")
          {:reply, [], state}

        [{metric, metric_type}] ->
          value =
            :ets.select(
              :telemetry,
              [
                {
                  {{:"$1", :"$2"}, :"$3"},
                  [{:>=, :"$1", start_ts}, {:<, :"$1", end_ts}, {:==, :"$2", metric}],
                  [[:"$1", :"$3"]]
                }
              ]
            )

          {metric_type, value}
      end

    {:reply, metrics, state}
  end

  def get_metrics(metric, start_ts, end_ts) do
    GenServer.call(
      __MODULE__,
      {:get_metrics, metric, start_ts, end_ts}
    )
  end

  def record(metric, value) do
    ts = :os.system_time(:second)

    case :ets.lookup(:metric_types, metric) do
      [] ->
        Logger.error("Unknown metric: #{metric}")

      [{metric, type}] ->
        record_metric(ts, metric, type, value)
    end
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
