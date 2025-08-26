defmodule PixelCanvas.SupervisorTest do
  use ExUnit.Case, async: false
  import PixelCanvas.TestHelper

  @moduletag :capture_log

  describe "server process restart behavior" do
    setup do
      server_pid = wait_for_server_ready()

      %{server_pid: server_pid}
    end

    test "server restarts when killed brutally", %{server_pid: original_pid} do
      # Kill the server process
      Process.exit(original_pid, :kill)

      # Wait for supervisor to restart it
      :timer.sleep(100)

      {_, new_pid, _, _} =
        Supervisor.which_children(PixelCanvas.Supervisor)
        |> Enum.find(fn {id, _, _, _} -> id == Infra.TcpListener end)

      # Verify new process is running
      assert new_pid != nil
      assert new_pid != original_pid
      assert Process.alive?(new_pid)
    end

    test "restarted server can accept new connections", %{server_pid: server_pid} do
      # Kill and restart server
      Process.exit(server_pid, :kill)
      :timer.sleep(100)

      # Verify new server can accept connections
      {:ok, client_socket} = :gen_tcp.connect(~c"localhost", 3000, [:binary, packet: :raw])
      assert client_socket != nil

      :gen_tcp.close(client_socket)
    end

    test "server restart preserves supervisor tree integrity", %{server_pid: original_pid} do
      supervisor_pid = Process.whereis(PixelCanvas.Supervisor)

      # Kill server
      Process.exit(original_pid, :kill)
      :timer.sleep(100)

      # Supervisor should still be running
      assert Process.alive?(supervisor_pid)

      # New server should be properly supervised
      children = Supervisor.which_children(PixelCanvas.Supervisor)
      assert Enum.any?(children, fn {id, _pid, _type, _modules} -> id == Infra.TcpListener end)
    end
  end

  describe "concurrent handler stress test" do
    setup do
      server_pid = wait_for_server_ready()
      %{server_pid: server_pid}
    end

    test "server survives rapid handler crashes", %{server_pid: server_pid} do
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
  end

  describe "resource cleanup" do
    # setup do
    #   wait_for_server_ready()
    #   :ok
    # end

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
  end
end
