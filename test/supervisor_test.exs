defmodule PixelCanvas.SupervisorTest do
  use ExUnit.Case, async: false
  import PixelCanvas.TestHelper

  @moduletag :capture_log

  describe "supervision tree startup" do
    setup do
      wait_for_server_ready()
      :ok
    end

    test "application starts supervision tree correctly" do
      # Verify the main supervisor is running
      assert Process.whereis(PixelCanvas.Supervisor) != nil

      # Verify server is running under supervisor
      server_pid = Process.whereis(PixelCanvas.Http.Server)
      assert server_pid != nil
      assert Process.alive?(server_pid)

      # Verify server is actually supervised
      children = Supervisor.which_children(PixelCanvas.Supervisor)
      assert Enum.any?(children, fn {_id, pid, _type, _modules} -> pid == server_pid end)
    end

    test "server starts with correct initial state" do
      server_pid = Process.whereis(PixelCanvas.Http.Server)
      state = :sys.get_state(server_pid)

      # Verify server has listening socket
      assert state.socket != nil

      # Verify server starts with no connection refs
      assert state.refs == %{}
    end

    test "server binds to configured port" do
      # Test that server actually binds to the port and can accept connections
      {:ok, client_socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])

      # Should be able to connect without error
      assert client_socket != nil

      :gen_tcp.close(client_socket)
    end
  end

  describe "server process restart behavior" do
    setup do
      wait_for_server_ready()

      :ok
    end

    test "server restarts when killed brutally" do
      original_pid = Process.whereis(PixelCanvas.Http.Server)

      # Kill the server process
      Process.exit(original_pid, :kill)

      # Wait for supervisor to restart it
      :timer.sleep(100)

      # Verify new process is running
      new_pid = Process.whereis(PixelCanvas.Http.Server)
      assert new_pid != nil
      assert new_pid != original_pid
      assert Process.alive?(new_pid)
    end

    test "server restarts when crashing with exception" do
      original_pid = Process.whereis(PixelCanvas.Http.Server)

      # Cause server to crash with an exception
      GenServer.cast(PixelCanvas.Http.Server, :crash_me)

      # Wait for the crash to propegate
      :timer.sleep(10)

      # Verify new process is running
      new_pid = wait_for_process(PixelCanvas.Http.Server, 1000)
      assert new_pid != nil
      assert new_pid != original_pid
      assert Process.alive?(new_pid)
    end

    test "restarted server can accept new connections" do
      original_pid = Process.whereis(PixelCanvas.Http.Server)

      # Kill and restart server
      Process.exit(original_pid, :kill)
      :timer.sleep(100)

      # Verify new server can accept connections
      {:ok, client_socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
      assert client_socket != nil

      :gen_tcp.close(client_socket)
    end

    test "server restart preserves supervisor tree integrity" do
      original_pid = Process.whereis(PixelCanvas.Http.Server)
      supervisor_pid = Process.whereis(PixelCanvas.Supervisor)

      # Kill server
      Process.exit(original_pid, :kill)
      :timer.sleep(100)

      # Supervisor should still be running
      assert Process.alive?(supervisor_pid)

      # New server should be properly supervised
      new_server_pid = Process.whereis(PixelCanvas.Http.Server)
      children = Supervisor.which_children(PixelCanvas.Supervisor)
      assert Enum.any?(children, fn {_id, pid, _type, _modules} -> pid == new_server_pid end)
    end
  end

  describe "handler isolation" do
    setup do
      wait_for_server_ready()
      :ok
    end

    test "handler crash does not affect server process" do
      server_pid = Process.whereis(PixelCanvas.Http.Server)

      # Connect and send malformed request to crash handler
      {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, active: false])
      :gen_tcp.send(socket, "MALFORMED REQUEST THAT SHOULD CRASH HANDLER\\r\\n\\r\\n")

      # Wait for potential crash propagation
      :timer.sleep(100)

      # Server should still be alive and responding
      assert Process.alive?(server_pid)

      # Should be able to make new connection
      {:ok, socket2} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
      assert socket2 != nil

      :gen_tcp.close(socket)
      :gen_tcp.close(socket2)
    end

    test "multiple handler crashes are isolated from each other" do
      # Create multiple connections that will crash
      sockets =
        for _i <- 1..5 do
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
          socket
        end

      # Send malformed requests to crash all handlers
      for socket <- sockets do
        :gen_tcp.send(socket, "CRASH ME\\r\\n\\r\\n")
      end

      # Wait for crashes
      :timer.sleep(200)

      # Server should still be responsive
      {:ok, test_socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
      assert test_socket != nil

      # Clean up
      for socket <- [test_socket | sockets] do
        :gen_tcp.close(socket)
      end
    end

    test "server can handle connections during handler crashes" do
      # Start a connection that will crash
      {:ok, crash_socket} =
        :gen_tcp.connect(~c"localhost", 3000, [:binary, active: false, packet: :raw])

      # Start a normal connection
      {:ok, normal_socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, active: false])

      # Crash one handler
      :gen_tcp.send(crash_socket, "CRASH\r\n\r\n")

      # Normal connection should still work
      :gen_tcp.send(normal_socket, "GET / HTTP/1.1\\r\\nHost: localhost\\r\\n\\r\\n")

      # Should receive some response (even if error)
      assert {:ok, data} = :gen_tcp.recv(crash_socket, 0)

      :gen_tcp.close(crash_socket)
      :gen_tcp.close(normal_socket)
    end
  end

  describe "concurrent handler stress test" do
    setup do
      wait_for_server_ready()
      :ok
    end

    test "server survives rapid handler crashes" do
      server_pid = Process.whereis(PixelCanvas.Http.Server)

      # Spawn many concurrent connections that will crash
      tasks =
        for _i <- 1..20 do
          Task.async(fn ->
            {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
            :gen_tcp.send(socket, "INVALID\\r\\n\\r\\n")
            :gen_tcp.close(socket)
          end)
        end

      # Wait for all to complete
      Enum.each(tasks, &Task.await/1)

      # Server should still be alive
      assert Process.alive?(server_pid)

      # Should be able to make new connection
      {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
      assert socket != nil
      :gen_tcp.close(socket)
    end

    test "connection count tracking survives handler crashes" do
      # Get initial connection count
      initial_state = :sys.get_state(Process.whereis(PixelCanvas.Http.Server))
      initial_count = initial_state.refs |> Map.keys() |> length()

      # Create connections that will crash
      for _i <- 1..10 do
        spawn(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
          :gen_tcp.send(socket, "CRASH\\r\\n\\r\\n")
          :gen_tcp.close(socket)
        end)
      end

      # Wait for crashes and cleanup
      :timer.sleep(500)

      # Connection count should return to initial state
      final_state = :sys.get_state(Process.whereis(PixelCanvas.Http.Server))
      assert final_state.refs |> Map.keys() |> length() == initial_count
    end
  end

  describe "resource cleanup" do
    setup do
      wait_for_server_ready()
      :ok
    end

    test "handlers properly clean up socket resources" do
      initial_ports = length(:erlang.ports())

      # Create many connections that will complete normally
      tasks =
        for _i <- 1..20 do
          Task.async(fn ->
            {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
            :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
            # Let handler process the request and close
            :timer.sleep(10)
            :gen_tcp.close(socket)
          end)
        end

      # Wait for all connections to complete
      Enum.each(tasks, &Task.await/1)

      # Allow time for cleanup
      :timer.sleep(200)

      # Port count should return to baseline (or close to it)
      final_ports = length(:erlang.ports())
      # Small tolerance
      assert final_ports <= initial_ports + 2
    end

    test "handlers don't leak connection references" do
      server_pid = Process.whereis(PixelCanvas.Http.Server)
      initial_refs = :sys.get_state(server_pid).refs |> map_size()

      # Create connections that complete normally
      for _i <- 1..10 do
        spawn(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
          :gen_tcp.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
          :timer.sleep(50)
          :gen_tcp.close(socket)
        end)
      end

      # Wait for cleanup
      :timer.sleep(500)

      # Should have same number of refs (no leaks)
      final_refs = :sys.get_state(server_pid).refs |> map_size()
      assert final_refs == initial_refs
    end
  end

  # Helper function to force server to crash (implement in your server)
  defp crash_server do
    GenServer.cast(PixelCanvas.Http.Server, :crash_me)
  end
end
