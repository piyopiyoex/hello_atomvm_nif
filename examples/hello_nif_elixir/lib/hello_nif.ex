defmodule HelloNif do
  @moduledoc """
  Minimal example of an AtomVM NIF called from Elixir.

  On AtomVM, `HelloNif.hello/0` is implemented as the native function
  `"Elixir.HelloNif:hello/0"` in C.
  """

  @doc """
  Returns a value from the native implementation when running on AtomVM.

  When running on the BEAM without the NIF, this simple fallback is used.
  """
  def hello do
    "NIF not loaded"
  end
end

