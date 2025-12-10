defmodule SampleApp do
  @moduledoc """
  Minimal AtomVM application that calls `HelloNif.hello/0`.
  """

  def start(_args \\ []) do
    msg = HelloNif.hello()
    IO.puts("NIF said: #{msg}")
    :ok
  end
end

