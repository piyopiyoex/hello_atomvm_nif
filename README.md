# Hello AtomVM NIF

A tiny “hello world” AtomVM NIF (ESP-IDF component) called from an Elixir app on ESP32.

This repo includes:

- A native NIF collection written in C (`sample_app_hello`)
- A minimal Elixir example that calls the NIF and prints results

Tested on ESP32-S3, but intended to work on ESP32 targets supported by AtomVM + ESP-IDF.

![](https://github.com/user-attachments/assets/b4e8b4b9-c2fa-4f78-894d-d52e3b51fb7c)

## Quickstart

```sh
git clone https://github.com/piyopiyoex/hello_atomvm_nif.git
cd hello_atomvm_nif

# Build + flash AtomVM firmware (includes this ESP-IDF component)
bash scripts/atomvm-esp32.sh install --target esp32s3 --port /dev/ttyACM0

# Build + flash the Elixir example app
cd examples/elixir
mix deps.get
mix do clean + atomvm.esp32.flash --port /dev/ttyACM0

# Monitor serial output
cd ../..
bash scripts/atomvm-esp32.sh monitor --port /dev/ttyACM0
```

## What’s in this repo

- `nifs/`
  - ESP-IDF component that registers NIFs for `SampleApp.Hello`
- `examples/elixir/`
  - Elixir app that calls the NIFs and prints results periodically

## API

The NIFs are exposed to Elixir as regular functions:

- `SampleApp.Hello.ping/0`
  - returns `:ok` (or `{:error, :badarg}` on invalid call)

- `SampleApp.Hello.echo/1`
  - returns `{:ok, payload}` (or `{:error, :badarg}` if payload is not a binary)

Under the hood AtomVM resolves these via NIF names:

- `"Elixir.SampleApp.Hello:ping/0"`
- `"Elixir.SampleApp.Hello:echo/1"`

## How it works

Message flow:

```text
Elixir process -> NIF (C) -> return value -> Elixir
```

This is a direct function call into native code (unlike ports, no mailbox or `:port.call/2` is involved).

## Build and run

### Clone repos

```sh
# Paths (adjust if you want)
ATOMVM_REPO_PATH="$HOME/atomvm/AtomVM"
ATOMVM_ESP32_PATH="$ATOMVM_REPO_PATH/src/platforms/esp32"
NIF_COMPONENT_PATH="$ATOMVM_ESP32_PATH/components/hello_atomvm_nif"

# Clone AtomVM
git clone https://github.com/atomvm/AtomVM.git "$ATOMVM_REPO_PATH"

# Clone this example directly into AtomVM's ESP32 components directory
git clone https://github.com/piyopiyoex/hello_atomvm_nif.git "$NIF_COMPONENT_PATH"
```

### Configure partition table for the Elixir app

AtomVM needs a partition table that includes the Elixir partition (`main.avm`).

Edit `"$ATOMVM_ESP32_PATH/sdkconfig.defaults"` and ensure it contains:

```ini
CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="partitions-elixir.csv"
```

### Build and flash AtomVM firmware

```sh
cd "$ATOMVM_ESP32_PATH"

source "$HOME/esp/esp-idf/export.sh"

idf.py fullclean
idf.py set-target esp32s3
idf.py build
idf.py -p /dev/ttyACM0 flash
```

> If you’re using a different ESP32 target, change the `set-target` value accordingly.

### Build and flash the Elixir app

```sh
HELLO_NIF_PATH="$ATOMVM_ESP32_PATH/components/hello_atomvm_nif"

cd "$HELLO_NIF_PATH/examples/elixir"

mix deps.get
mix do clean + atomvm.esp32.flash --port /dev/ttyACM0
```

### Monitor serial output

```sh
cd "$ATOMVM_ESP32_PATH"
idf.py -p /dev/ttyACM0 monitor
```

## Expected output

```text
Starting application...
Ping: :ok
Echo request: "hello from Elixir: 1700000000"
Echo reply: "hello from Elixir: 1700000000"
```

## Troubleshooting

- If you see `:nif_not_loaded`, you likely flashed only the Elixir app
  (`main.avm`) but not the AtomVM firmware that includes this component.
- If you changed module/function names, confirm the NIF names in
  `nifs/sample_app_hello.c` still match: `"Elixir.SampleApp.Hello:ping/0"` and
  `"Elixir.SampleApp.Hello:echo/1"`.
