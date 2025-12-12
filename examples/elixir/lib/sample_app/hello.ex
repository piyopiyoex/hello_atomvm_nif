defmodule SampleApp.Hello do
  @moduledoc """
  Minimal AtomVM NIF wrapper.

  On AtomVM, these functions are implemented in C and exposed via NIF names:

  - `"Elixir.SampleApp.Hello:ping/0"`
  - `"Elixir.SampleApp.Hello:echo/1"`
  """

  @spec ping() :: :ok | {:error, :badarg} | :nif_not_loaded
  def ping do
    :nif_not_loaded
  end

  @spec echo(binary()) :: {:ok, binary()} | {:error, :badarg} | :nif_not_loaded
  def echo(_payload) do
    :nif_not_loaded
  end
end
