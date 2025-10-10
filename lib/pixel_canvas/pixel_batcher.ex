defmodule PixelCanvas.PixelBatcher do
  use GenServer
  require Logger
  alias PixelCanvas.Pixel
  @refresh_rate_ms 17

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(:pixel_buffer_a, [:set, :public, :named_table])
    :ets.new(:pixel_buffer_b, [:set, :public, :named_table])
    :persistent_term.put(:active_buffer, :pixel_buffer_a)

    timer = Process.send_after(self(), :flush, @refresh_rate_ms)

    {:ok,
     %{
       timer: timer,
       active: :pixel_buffer_a,
       inactive: :pixel_buffer_b
     }}
  end

  def batch(storage_pixels) do
    Enum.each(storage_pixels, &:ets.insert(:persistent_term.get(:active_buffer), &1))
  end

  def handle_info(:flush, state) do
    broadcaster_info =
      Process.whereis(Infra.WebSocket.Broadcaster)
      |> Process.info()

    cond do
      broadcaster_info[:message_queue_len] < 1000 ->
        new_active = state.inactive
        old_active = state.active

        :persistent_term.put(:active_buffer, new_active)

        pixels = :ets.tab2list(old_active)
        :ets.delete_all_objects(old_active)

        if length(pixels) > 0 do
          pixels
          # TODO: we can skip this step to pixel structs and convert the storage format
          # to the binary client format
          |> Enum.map(fn {{region_x, region_y, local_x, local_y}, user_id, color} ->
            %Pixel{
              region_x: region_x,
              region_y: region_y,
              local_x: local_x,
              local_y: local_y,
              color: color,
              user_id: user_id,
              opcode: 1
            }
          end)
          |> Pixel.encode_server_pixels()
          |> Enum.each(fn message ->
            Infra.WebSocket.Broadcaster.broadcast(message)
          end)
        end

        timer = Process.send_after(self(), :flush, @refresh_rate_ms)

        {:noreply,
         %{
           state
           | active: new_active,
             inactive: old_active,
             timer: timer
         }}

      true ->
        timer = Process.send_after(self(), :flush, @refresh_rate_ms)
        {:noreply, %{state | timer: timer}}
    end
  end
end
