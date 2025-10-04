defmodule Mix.Tasks.LoadTest do
  use Mix.Task
  require Logger

  def run([]) do
    host = "localhost"
    port = "3000"
    run([host, port])
  end

  def run([host, port]) do
    run([host, port, "100"])
  end

  def run([host, port, count]) do
    port = String.to_integer(port)
    count = String.to_integer(count)

    if host == "localhost" do
      Mix.Task.run("app.start")
      :timer.sleep(100)
    end

    TestStats.start_link()

    start_connections(host, port, count)
  end

  def run(args) do
    IO.puts("Invalid arguments: #{inspect(args)}")
  end

  defp start_connections(host, port, count, start \\ 1) do
    for i <- start..(start + count - 1) do
      # :timer.sleep(1000)
      {:ok, conn} = TestConnection.start_link(host, port, i)
      conn
    end
  end
end
