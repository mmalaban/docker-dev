FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Base Dependencies
# Union of packages from both Zephyr and GNU Arm Dockerfiles
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake ninja-build gperf \
    ccache dfu-util device-tree-compiler wget \
    python3-dev python3-pip python3-setuptools python3-tk python3-wheel xz-utils file \
    make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 \
    ca-certificates curl \
    gdb-multiarch \
    autoconf automake libtool pkg-config texinfo \
    stlink-tools \
    udev usbutils \
    libusb-1.0-0 libusb-1.0-0-dev \
    libftdi1-2 libftdi1-dev \
    libhidapi-hidraw0 libhidapi-dev \
    libjaylink0 libjaylink-dev \
    libjim-dev \
    locales \
    bzip2 \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# 2. Set Locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# 3. Install GNU Arm Embedded Toolchain
# Needed for libopencm3 and non-Zephyr bare-metal projects
ARG ARM_TOOLCHAIN_VERSION=14.3.rel1
ARG ARM_TOOLCHAIN_BASE_URL=https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel
ARG ARM_TOOLCHAIN_FILENAME=arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-x86_64-arm-none-eabi.tar.xz
ARG ARM_TOOLCHAIN_INSTALL_DIR=/opt/gcc-arm-none-eabi

RUN wget -q "${ARM_TOOLCHAIN_BASE_URL}/${ARM_TOOLCHAIN_FILENAME}" -O /tmp/gcc-arm.tar.xz \
    && mkdir -p ${ARM_TOOLCHAIN_INSTALL_DIR} \
    && tar -xf /tmp/gcc-arm.tar.xz -C ${ARM_TOOLCHAIN_INSTALL_DIR} --strip-components=1 \
    && rm /tmp/gcc-arm.tar.xz

ENV PATH="/opt/gcc-arm-none-eabi/bin:${PATH}"

# 4. Install Zephyr SDK
ARG ZEPHYR_SDK_VERSION=0.17.4
ARG ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk
ENV ZEPHYR_SDK_INSTALL_DIR=${ZEPHYR_SDK_INSTALL_DIR}
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr

RUN wget -q "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64_minimal.tar.xz" -O /tmp/zephyr-sdk.tar.xz \
    && mkdir -p ${ZEPHYR_SDK_INSTALL_DIR} \
    && tar -xf /tmp/zephyr-sdk.tar.xz -C ${ZEPHYR_SDK_INSTALL_DIR} --strip-components=1 \
    && ${ZEPHYR_SDK_INSTALL_DIR}/setup.sh \
       -t arm-zephyr-eabi \
       -t riscv64-zephyr-elf \
       -t xtensa-espressif_esp32_zephyr-elf \
       -t xtensa-espressif_esp32s2_zephyr-elf \
       -t xtensa-espressif_esp32s3_zephyr-elf \
       -h -c \
    && rm /tmp/zephyr-sdk.tar.xz

ENV PATH="${ZEPHYR_SDK_INSTALL_DIR}/arm-zephyr-eabi/bin:${ZEPHYR_SDK_INSTALL_DIR}/riscv64-zephyr-elf/bin:${ZEPHYR_SDK_INSTALL_DIR}/xtensa-espressif_esp32_zephyr-elf/bin:${ZEPHYR_SDK_INSTALL_DIR}/xtensa-espressif_esp32s2_zephyr-elf/bin:${ZEPHYR_SDK_INSTALL_DIR}/xtensa-espressif_esp32s3_zephyr-elf/bin:${PATH}"

# 5. Install Espressif RISC-V GDB (32-bit, for ESP32-C3 debugging)
ARG ESP_GDB_VERSION=16.3_20250913
RUN wget -q "https://github.com/espressif/binutils-gdb/releases/download/esp-gdb-v${ESP_GDB_VERSION}/riscv32-esp-elf-gdb-${ESP_GDB_VERSION}-x86_64-linux-gnu.tar.gz" -O /tmp/esp-gdb.tar.gz \
    && mkdir -p /opt/esp-gdb \
    && tar -xf /tmp/esp-gdb.tar.gz -C /opt/esp-gdb --strip-components=1 \
    && rm /tmp/esp-gdb.tar.gz

ENV PATH="/opt/esp-gdb/bin:${PATH}"

# 6. Build OpenOCD (Espressif fork — upstream OpenOCD + ESP32 support)
# Enables all common debug adapter interfaces
RUN git clone --depth 1 https://github.com/espressif/openocd-esp32.git /tmp/openocd-esp32 \
    && cd /tmp/openocd-esp32 \
    && ./bootstrap \
    && ./configure \
       --enable-ftdi \
       --enable-stlink \
       --enable-jlink \
       --enable-cmsis-dap \
       --enable-esp-usb-jtag \
       --disable-werror \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/openocd-esp32

# 7. Install West & Python Dependencies
RUN pip3 install --break-system-packages west esptool

# 8. Setup Zephyr Workspace (Freestanding Setup)
ENV ZEPHYR_BASE=/opt/zephyrproject/zephyr
RUN west init -m https://github.com/zephyrproject-rtos/zephyr --mr main /opt/zephyrproject \
    && cd /opt/zephyrproject \
    && west update --narrow --fetch-opt=--depth=1 \
    && west zephyr-export \
    && pip3 install --break-system-packages -r /opt/zephyrproject/zephyr/scripts/requirements.txt \
    && find /opt/zephyrproject -name ".git" -type d -exec rm -rf {} +

# 9. Build libopencm3
ENV OPENCM3_DIR=/opt/libopencm3
RUN git clone --depth 1 https://github.com/libopencm3/libopencm3.git ${OPENCM3_DIR} \
    && make -C ${OPENCM3_DIR} -j$(nproc) \
    && rm -rf ${OPENCM3_DIR}/.git

# 10. Debugging & Tools Setup
# udev rules for Black Magic Probe
RUN echo 'SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", SYMLINK+="ttyBmpGdb", MODE="0666"' > /etc/udev/rules.d/99-blackmagic.rules \
    && echo 'SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", SYMLINK+="ttyBmpTarg", MODE="0666"' >> /etc/udev/rules.d/99-blackmagic.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="6018", MODE="0666"' >> /etc/udev/rules.d/99-blackmagic.rules

# udev rules for ST-Link
RUN echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="0666"' > /etc/udev/rules.d/99-stlink.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", MODE="0666"' >> /etc/udev/rules.d/99-stlink.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", MODE="0666"' >> /etc/udev/rules.d/99-stlink.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", MODE="0666"' >> /etc/udev/rules.d/99-stlink.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", MODE="0666"' >> /etc/udev/rules.d/99-stlink.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3752", MODE="0666"' >> /etc/udev/rules.d/99-stlink.rules \
    && echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", MODE="0666"' >> /etc/udev/rules.d/99-stlink.rules

# udev rules for Segger J-Link
RUN echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1366", MODE="0666"' > /etc/udev/rules.d/99-jlink.rules

# udev rules for FTDI-based adapters (Olimex, Digilent, etc.)
RUN echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", MODE="0666"' > /etc/udev/rules.d/99-ftdi.rules

# udev rules for CMSIS-DAP / DAPLink
RUN echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0d28", MODE="0666"' > /etc/udev/rules.d/99-cmsis-dap.rules

# udev rules for Espressif USB JTAG
RUN echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="303a", MODE="0666"' > /etc/udev/rules.d/99-espressif.rules \
    && echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", MODE="0666"' >> /etc/udev/rules.d/99-espressif.rules

# GDB Init
RUN mkdir -p /root/.config/gdb \
    && printf 'set auto-load safe-path /\n' > /root/.gdbinit

# 11. Shell Setup
# Oh My Posh
RUN curl -L https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -o /usr/local/bin/oh-my-posh \
    && chmod +x /usr/local/bin/oh-my-posh \
    && printf '\n# oh-my-posh\n%s\n' 'eval "$(oh-my-posh init bash --config robbyrussell)"' >> /etc/bash.bashrc

# 12. Final Configuration
WORKDIR /workspace
CMD ["/bin/bash"]
