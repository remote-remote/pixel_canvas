defmodule TestConnection do
  use GenServer
  require Logger

  alias PixelCanvas.PixelStore
  alias PixelCanvas.Pixel
  alias Infra.WebSocket.Frame

  def start_link(id) do
    GenServer.start_link(__MODULE__, :ok, name: String.to_atom("test_connection_#{id}"))
  end

  def init(:ok) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw, active: false])

    {:ok,
     %{
       socket: socket,
       send_rate: 1,
       messages_per_send: 100,
       messages_sent: 0,
       messages_received: 0
     }, {:continue, :start}}
  end

  def handle_continue(:start, state) do
    initiate_websocket(state.socket)
    Process.send_after(self(), :send_pixels, Integer.floor_div(1000, state.send_rate))
    {:noreply, state}
  end

  def initiate_websocket(socket) do
    :gen_tcp.send(socket, """
    GET /ws HTTP/1.1\r
    Host: localhost\r
    Connection: Upgrade\r
    Upgrade: websocket\r
    Sec-WebSocket-Version: 13\r
    Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==\r
    \r
    """)

    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        Logger.info("Websocket upgrade response: #{inspect(data)}")

      other ->
        Logger.info("Didn't get good response: #{inspect(other)}")
    end
  end

  def send_pixels(state) do
    payload =
      Enum.map(1..state.messages_per_send, fn _ -> generate_pixel() end)
      |> Pixel.encode_many()
      |> Frame.construct()

    :gen_tcp.send(state.socket, payload)
  end

  def generate_pixel do
    %PixelCanvas.Pixel{
      opcode: 0,
      region_x: :rand.uniform(1024),
      region_y: :rand.uniform(1024),
      local_x: :rand.uniform(1024),
      local_y: :rand.uniform(1024),
      color: "000"
    }
  end

  def handle_info(:send_pixels, state) do
    send_pixels(state)
    Process.send_after(self(), :send_pixels, Integer.floor_div(1000, state.send_rate))
    {:noreply, state}
  end
end
