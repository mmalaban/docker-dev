#!/bin/bash

DEVICE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        *)
            echo "Error: Unexpected argument '$1'."
            echo "Usage: ./docker-run.sh [-d|--device <device>]"
            exit 1
            ;;
    esac
done

DEVICE_FLAG=""
if [ -n "$DEVICE" ]; then
    DEVICE_FLAG="--device=$DEVICE:$DEVICE"
fi

echo "Starting MCU dev container..."
docker run -it --rm --privileged $DEVICE_FLAG -p 3333:3333 -p 4444:4444 -p 6666:6666 -v $(pwd):/workspace mcu-dev
