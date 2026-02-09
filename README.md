# MCU Development Container

A unified Docker image for embedded development targeting STM32, ESP32, RISC-V, and ARM Cortex-M/A using Zephyr, libopencm3, and bare-metal toolchains.

## What's Included

- **GNU Arm Embedded Toolchain** (`arm-none-eabi-gcc`) — for libopencm3 and bare-metal projects
- **Zephyr SDK** — `arm-zephyr-eabi`, `riscv64-zephyr-elf`, and ESP32 Xtensa toolchains
- **Zephyr RTOS** — freestanding workspace at `/opt/zephyrproject`
- **libopencm3** — built and installed at `/opt/libopencm3` (`OPENCM3_DIR` env var set)
- **Espressif OpenOCD** — built from source with ESP32 USB JTAG support
- **West & esptool** — Zephyr meta-tool and ESP32 flashing
- **Debugging** — `gdb-multiarch`, `stlink-tools`, udev rules for BMP and ST-Link
- **Shell** — Oh My Posh, tmux

## Build

```bash
docker build -t mcu-dev .
```

## Run

```bash
./docker-run.sh
```

With a device passed through:

```bash
./docker-run.sh -d /dev/ttyACM0
```
