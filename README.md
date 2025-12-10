# atomvm_hello_nif

Minimal example of an AtomVM NIF written in C and called from an Elixir
application running on an ESP32-S3.

The `atomvm_hello_nif` directory is an ESP-IDF component that must be added
to an AtomVM ESP32 build (for example by placing or symlinking it under
`src/platforms/esp32/components/` in the AtomVM tree).

The `examples/hello_nif_elixir` directory contains a small Elixir project
that:

- defines `HelloNif.hello/0`, and
- calls it from `SampleApp.start/1`.

On AtomVM, `HelloNif.hello/0` is implemented as the NIF
`"Elixir.HelloNif:hello/0"` in `nifs/hello_nif.c`, which currently returns
the integer `1234`.

High-level flow:

1. Build AtomVM for ESP32-S3 with this component included.
2. Build the Elixir example with `mix atomvm.packbeam`.
3. Flash the firmware and the generated `sample_app.avm` to the board.
4. Open a serial console and you should see:

   ```text
   Starting application...
   NIF said: 1234
   Return value: ok
   ```
This repository is intended as a minimal, readable reference for wiring a
custom NIF into an AtomVM-based ESP32 firmware and using it from Elixir.
