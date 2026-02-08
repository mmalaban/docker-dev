#!/bin/bash

DEVICE=""
TOOLCHAIN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        *)
            if [ -z "$TOOLCHAIN" ]; then
                TOOLCHAIN="$1"
            else
                echo "Error: Unexpected argument '$1'."
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$TOOLCHAIN" ]; then
    echo "Error: No argument provided. Please provide either 'zephyr' or 'gnu-arm'."
    exit 1
fi

DEVICE_FLAG=""
if [ -n "$DEVICE" ]; then
    DEVICE_FLAG="--device=$DEVICE:$DEVICE"
fi

if [ "$TOOLCHAIN" == "zephyr" ]; then
    echo "Starting Zephyr container..."
    docker run -it --rm --privileged $DEVICE_FLAG -v $(pwd):/workspace zephyr-dev
elif [ "$TOOLCHAIN" == "gnu-arm" ]; then
    echo "Starting GNU Arm container..."
    docker run -it --rm --privileged $DEVICE_FLAG -v $(pwd):/workspace gnu-arm-dev
else
    echo "Error: Invalid argument. Please provide either 'zephyr' or 'gnu-arm'."
    exit 1
fi
