defmodule TestStats do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok,
     %{
       failed_connections: 0,
       total_messages_sent: 0,
       total_messages_received: 0,
       max_message_per_second: 0
     }}
  end

  def add_messages_sent(count) do
    GenServer.cast(__MODULE__, {:add_messages_sent, count})
  end

  def add_messages_received(count) do
    GenServer.cast(__MODULE__, {:add_messages_received, count})
  end

  def handle_cast({:add_messages_sent, count}, state) do
    {:noreply, Map.update!(state, :total_messages_sent, &(&1 + count))}
  end

  def handle_cast({:add_messages_received, count}, state) do
    {:noreply, Map.update!(state, :total_messages_received, &(&1 + count))}
  end
end
