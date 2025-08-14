defmodule PixelCanvas.Http.ServerTest do
  use ExUnit.Case, async: true
  alias PixelCanvas.Http.Server

  @moduletag capture_log: true

  describe "start_link/1" do
    test "starts the HTTP server on the specified port" do
      port = 4001
      assert {:ok, pid} = Server.start_link(port: port)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "returns error when port is already in use" do
      port = 4002
      assert {:ok, pid1} = Server.start_link(port: port)
      assert {:error, :eaddrinuse} = Server.start_link(port: port)
      GenServer.stop(pid1)
    end
  end

  describe "HTTP request handling" do
    setup do
      port = :rand.uniform(1000) + 5000
      {:ok, server_pid} = Server.start_link(port: port)

      # this seems to work as expected when running the describe block
      # but when running a single test, the process is already dead
      on_exit(fn ->
        if Process.alive?(server_pid), do: GenServer.stop(server_pid)
      end)

      %{port: port, server_pid: server_pid}
    end

    test "handles GET request to root path", %{port: port} do
      response = make_http_request(port, "GET", "/", "")

      assert response =~ "HTTP/1.1 200 OK"
      assert response =~ "Content-Type: text/plain"
      assert response =~ "PixelCanvas Server"
    end

    test "handles POST request with body", %{port: port} do
      body = "test data"
      response = make_http_request(port, "POST", "/api/pixels", body)

      assert response =~ "HTTP/1.1 200 OK"
      assert response =~ "Content-Type: application/json"
    end

    test "returns 404 for unknown paths", %{port: port} do
      response = make_http_request(port, "GET", "/unknown", "")

      assert response =~ "HTTP/1.1 404 Not Found"
    end

    test "handles malformed requests gracefully", %{port: port} do
      {:ok, socket} =
        :gen_tcp.connect(~c"localhost", port, [:binary, active: false, packet: :raw])

      :ok = :gen_tcp.send(socket, "INVALID HTTP REQUEST\r\n\r\n")

      {:ok, response} = :gen_tcp.recv(socket, 0, 1000)
      :gen_tcp.close(socket)

      assert response =~ "HTTP/1.1 400 Bad Request"
    end

    test "handles concurrent requests", %{port: port} do
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            make_http_request(port, "GET", "/", "")
          end)
        end

      responses = Task.await_many(tasks, 5000)

      assert length(responses) == 10

      Enum.each(responses, fn response ->
        assert response =~ "HTTP/1.1 200 OK"
      end)
    end
  end

  describe "server state management" do
    setup do
      port = :rand.uniform(1000) + 6000
      {:ok, server_pid} = Server.start_link(port: port)

      # Establish a few connections to ensure connection count > 0
      sockets =
        for _ <- 1..3 do
          {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, active: false])
          socket
        end

      on_exit(fn ->
        # Close the test connections
        Enum.each(sockets, &:gen_tcp.close/1)

        if Process.alive?(server_pid), do: GenServer.stop(server_pid)
      end)

      %{port: port, server_pid: server_pid, sockets: sockets}
    end

    test "maintains connection count", %{server_pid: server_pid} do
      # This test assumes the server tracks active connections
      initial_count = GenServer.call(server_pid, :get_connection_count)
      assert is_integer(initial_count)
      assert initial_count >= 1
    end

    test "can be gracefully stopped", %{server_pid: server_pid} do
      assert Process.alive?(server_pid)
      assert :ok = GenServer.stop(server_pid)
      refute Process.alive?(server_pid)
    end
  end

  # Helper function to make raw HTTP requests
  defp make_http_request(port, method, path, body) do
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
end
