defmodule TestConnection do
  use GenServer
  require Logger

  alias PixelCanvas.Pixel
  alias Infra.WebSocket.Frame

  def start_link(host, port, id) do
    GenServer.start_link(__MODULE__, {host, port}, name: String.to_atom("test_connection_#{id}"))
  end

  def init({host, port}) do
    case :gen_tcp.connect(~c"#{host}", port, [:binary, packet: :raw, active: false]) do
      {:ok, socket} ->
        r = :rand.uniform(16) - 1
        g = :rand.uniform(16) - 1
        b = :rand.uniform(16) - 1
        color = <<r::integer-4, g::integer-4, b::integer-4, 15::integer-4>>
        position = {:rand.uniform(1024) - 1, :rand.uniform(1024) - 1}
        direction = {:rand.uniform(3) - 2, :rand.uniform(3) - 2}

        {:ok,
         %{
           socket: socket,
           host: host,
           port: port,
           send_rate: :rand.uniform(100) + 10,
           position: position,
           direction: direction,
           color: color,
           messages_sent: 0,
           messages_received: 0,
           buffer: <<>>,
           frame_buffer: []
         }, {:continue, :start}}

      other ->
        Logger.info("Didn't get good response: #{inspect(other)}")
        {:stop, :no_connection}
    end
  end

  def handle_continue(:start, state) do
    initiate_websocket(state)
    Process.send_after(self(), :send_pixel, round(1000 / state.send_rate))
    {:noreply, state}
  end

  def initiate_websocket(state) do
    :gen_tcp.send(state.socket, """
    GET /ws HTTP/1.1\r
    Host: #{state.host}\r
    Connection: Upgrade\r
    Upgrade: websocket\r
    Sec-WebSocket-Version: 13\r
    Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
    \r
    """)

    case :gen_tcp.recv(state.socket, 0) do
      {:ok, data} ->
        Logger.info("Websocket upgrade response: #{inspect(data)}")

      other ->
        Logger.info("Didn't get good response: #{inspect(other)}")
    end

    :inet.setopts(state.socket, active: true)
  end

  def send_pixel(state) do
    payload =
      state
      |> generate_pixel()
      |> Pixel.encode_one()
      |> Frame.construct_masked(<<0, 0, 0, 0>>)

    :gen_tcp.send(state.socket, payload)
    TestStats.add_messages_sent(1)
  end

  def generate_pixel(state) do
    {x, y} = state.position

    %PixelCanvas.Pixel{
      opcode: 0,
      region_x: 0,
      region_y: 0,
      local_x: x,
      local_y: y,
      color: state.color
    }
  end

  def handle_cast({:change_rate, rate}, state) do
    {:noreply, %{state | send_rate: rate}}
  end

  def handle_info(:send_pixel, state) do
    {x, y} = state.position
    {vx, vy} = state.direction
    new_vx = if vx + x < 0 || vx + x > 1023, do: vx * -1, else: vx
    new_vy = if vy + y < 0 || vy + y > 1023, do: vy * -1, else: vy
    new_x = x + new_vx
    new_y = y + new_vy

    case send_pixel(state) do
      :ok ->
        Process.send_after(self(), :send_pixel, round(1000 / state.send_rate))

      {:error, reason} ->
        Logger.error("Error sending pixels: #{inspect(reason)}")
        Process.send_after(self(), :send_pixel, round(1000 / state.send_rate))
    end

    state =
      Map.put(state, :position, {new_x, new_y})
      |> Map.put(:direction, {new_vx, new_vy})

    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, state) do
    case Frame.parse_no_mask(state.buffer <> data) do
      :fragment ->
        {:noreply, Map.put(state, :buffer, data)}

      {%Frame{} = frame, rest} ->
        state = Map.put(state, :buffer, <<>>)

        state =
          if frame.fin == 1 do
            payload =
              if state.frame_buffer != [] do
                Enum.reverse([frame | state.frame_buffer])
                |> Enum.reduce(<<>>, fn frame, acc ->
                  acc <> frame.payload
                end)
              else
                frame.payload
              end

            _pixels = Pixel.parse_message(payload)
            TestStats.add_messages_received(1)
            # TODO: check if we got the pixels we sent
            Map.put(state, :frame_buffer, [])
          else
            Map.put(state, :frame_buffer, [frame | state.frame_buffer])
          end

        if byte_size(rest) > 0 do
          handle_info({:tcp, socket, rest}, state)
        else
          {:noreply, state}
        end
    end

    # Logger.info("Got data: #{inspect(data)}")
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Socket closed")
    {:stop, :normal, state}
  end
end
