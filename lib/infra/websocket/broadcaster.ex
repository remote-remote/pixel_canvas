defmodule Infra.WebSocket.Broadcaster do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def register(pid) do
    GenServer.call(__MODULE__, {:register, pid})
  end

  def unregister(pid) do
    GenServer.call(__MODULE__, {:unregister, pid})
  end

  def broadcast(message) do
    GenServer.cast(__MODULE__, {:broadcast, message})
  end

  def handle_call({:register, pid}, _from, state) do
    {:reply, :ok, Map.put(state, pid, pid)}
  end

  def handle_call({:unregister, pid}, _from, state) do
    {:reply, :ok, Map.delete(state, pid)}
  end

  def handle_cast({:broadcast, message}, state) do
    for {pid, _} <- state do
      send(pid, {:broadcast_message, message})
    end

    {:noreply, state}
  end
end
