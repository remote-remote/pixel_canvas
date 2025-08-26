defmodule TestStats do
  use GenServer

  def start_link(_opts) do
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
end
