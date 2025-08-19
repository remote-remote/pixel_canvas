defmodule PixelCanvas.TestHelper do
  # Helper function to wait for a process to be registered by name
  def wait_for_process(name, timeout \\ 1000) do
    start_time = System.monotonic_time(:millisecond)
    wait_for_process_loop(name, start_time, timeout)
  end

  defp wait_for_process_loop(name, start_time, timeout) do
    case Process.whereis(name) do
      nil ->
        if System.monotonic_time(:millisecond) - start_time > timeout do
          nil
        else
          :timer.sleep(10)
          wait_for_process_loop(name, start_time, timeout)
        end

      pid ->
        pid
    end
  end

  # Helper function to make raw HTTP requests
  def make_http_request(port, method, path, body) do
    content_length = byte_size(body)

    request =
      """
      #{method} #{path} HTTP/1.1\r
      Host: localhost:#{port}\r
      Content-Length: #{content_length}\r
      Connection: close\r
      \r
      #{body}
      """

    {:ok, socket} =
      :gen_tcp.connect(~c"localhost", port, [:binary, active: false])

    :ok = :gen_tcp.send(socket, request)

    response =
      case :gen_tcp.recv(socket, 0) do
        {:ok, response} ->
          response

        {:error, reason} ->
          {:error, reason}
      end

    :gen_tcp.close(socket)
    response
  end

  def wait_for_server_ready do
    Application.stop(:pixel_canvas)
    Application.start(:pixel_canvas)

    server_pid =
      case Process.whereis(PixelCanvas.Http.Server) do
        nil ->
          # Wait for startup if needed
          wait_for_process(PixelCanvas.Http.Server, 2000)

        pid when is_pid(pid) ->
          # Server exists, ensure it's responsive
          pid
      end

    # Verify server is actually accepting connections before test starts
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
    :gen_tcp.close(socket)
    server_pid
  end
end

ExUnit.start()
