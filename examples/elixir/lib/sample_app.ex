defmodule SampleApp do
  @moduledoc """
  Minimal example of calling native AtomVM NIFs on ESP32.

  The call flow is:

    Elixir process -> NIF (C) -> return value -> Elixir

  This module calls:

  - `SampleApp.Hello.ping/0`
  - `SampleApp.Hello.echo/1`

  periodically, printing results to the console.
  """

  @tick_interval_ms 10_000

  def start do
    loop()
  end

  defp loop do
    do_ping()
    do_echo()

    Process.sleep(@tick_interval_ms)
    loop()
  end

  defp do_ping do
    case SampleApp.Hello.ping() do
      :ok ->
        IO.puts("Ping: :ok")

      {:error, reason} ->
        IO.puts("Ping failed: #{inspect(reason)}")

      other ->
        IO.puts("Ping unexpected: #{inspect(other)}")
    end
  end

  defp do_echo do
    payload = "hello from Elixir: #{:erlang.system_time(:second)}"
    IO.puts("Echo request: #{inspect(payload)}")

    case SampleApp.Hello.echo(payload) do
      {:ok, echoed} ->
        IO.puts("Echo reply: #{inspect(echoed)}")

      {:error, reason} ->
        IO.puts("Echo failed: #{inspect(reason)}")

      other ->
        IO.puts("Echo unexpected: #{inspect(other)}")
    end
  end
end
