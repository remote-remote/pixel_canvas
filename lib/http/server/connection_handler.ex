defmodule PixelCanvas.Http.ConnectionHandler do
  use GenServer, restart: :temporary
  require Logger
  alias PixelCanvas.Http.{Request, Response, Router}

  defstruct [:conn, :state, :protocol]

  def start_link(conn, opts \\ []) do
    Logger.debug("start_link called with conn: #{inspect(conn)}")
    GenServer.start_link(__MODULE__, conn, opts)
  end

  def init(conn) do
    Logger.debug("init called with conn: #{inspect(conn)}")

    {:ok,
     %__MODULE__{
       conn: conn,
       protocol: :http,
       state: :initialized
     }, {:continue, :handle_request}}
  end

  def handle_continue(:handle_request, %__MODULE__{conn: conn} = state) do
    Logger.debug("Handling request: #{inspect(conn)}")

    response =
      case Request.parse(conn) do
        {:ok, %Request{} = request} ->
          Router.route(request)
          |> Response.prepare(request)

        {:http_error, reason} ->
          Logger.error("Error parsing request: #{inspect(reason)}")

          %Response{
            status_code: 400,
            status_message: "Bad Request"
          }

        {:error, :closed} ->
          {:error, :closed}

        {:error, error} ->
          Logger.error("Error parsing request: #{inspect(error)}")

          %Response{
            status_code: 500,
            status_message: "Internal Server Error"
          }
      end

    case response do
      %Response{} = response ->
        :gen_tcp.send(conn, Response.to_binary(response))

        if keep_alive?(response) do
          if is_websocket_upgrade?(response) do
            case PixelCanvas.WebSocket.Handler.start_link(conn) do
              {:ok, _handler} ->
                {:noreply, Map.put(state, :protocol, :websocket)}

              {:error, reason} ->
                Logger.error("Could not start websocket handler: #{inspect(reason)}")
                {:stop, :normal}
            end
          end
        else
          :gen_tcp.close(conn)
          {:stop, :normal, state}
        end

      {:error, :closed} ->
        Logger.error("Connection already closed")
        {:stop, :normal, state}

      _ ->
        Logger.error("Unknown parsing error: #{inspect(response)}")
        {:stop, :normal, state}
    end
  end

  defp is_websocket_upgrade?(%Response{headers: %{"Upgrade" => "websocket"}}), do: true
  defp is_websocket_upgrade?(%Response{}), do: false

  defp keep_alive?(%Response{headers: %{"Connection" => "keep-alive"}}), do: true
  defp keep_alive?(%Response{headers: %{"Connection" => "close"}}), do: false
  defp keep_alive?(%Response{status_code: 101}), do: true
  defp keep_alive?(%Response{}), do: false
end
