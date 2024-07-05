CROSS_COMPILE ?= riscv64-linux-gnu-
SOC = k230
BOARD ?= canmv
BUILD_DIR ?= output

CONFIG_DBGLV ?=0
export KCFLAGS=-DDBGLV=$(CONFIG_DBGLV)

all: sysimage-sdcard.img

u-boot: FORCE
	+$(MAKE) -C src/u-boot O=../../$(BUILD_DIR)/u-boot \
		ARCH=riscv CROSS_COMPILE="$(CROSS_COMPILE)" \
		$(SOC)_$(BOARD)_defconfig
	+$(MAKE) -C src/u-boot O=../../$(BUILD_DIR)/u-boot \
		ARCH=riscv CROSS_COMPILE="$(CROSS_COMPILE)"

opensbi: linux
	mkdir -p -- "$(BUILD_DIR)/opensbi"
	+$(MAKE) -C src/opensbi O="$(shell pwd)/$(BUILD_DIR)/opensbi" \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		PLATFORM=generic \
		FW_PAYLOAD_PATH="$(shell pwd)/$(BUILD_DIR)/linux/arch/riscv/boot/Image"

linux: FORCE
	+$(MAKE) -C src/linux O=../../$(BUILD_DIR)/linux \
		CROSS_COMPILE=$(CROSS_COMPILE) ARCH=riscv \
		$(SOC)_$(BOARD)_defconfig
	+$(MAKE) -C src/linux O=../../$(BUILD_DIR)/linux \
		CROSS_COMPILE=$(CROSS_COMPILE) ARCH=riscv

.PHONY: FORCE

FW_PAYLOAD = $(BUILD_DIR)/opensbi/platform/generic/firmware/fw_payload.bin
DTB = $(BUILD_DIR)/$(SOC)-$(BOARD).dtb
INITRD = $(BUILD_DIR)/initrd.img
ROOTFS = $(BUILD_DIR)/rootfs.ext4

$(BUILD_DIR)/u-boot/spl/u-boot-spl.bin: u-boot
$(BUILD_DIR)/u-boot/u-boot.bin: u-boot
$(FW_PAYLOAD): opensbi

$(BUILD_DIR)/u-boot-spl.bin: $(BUILD_DIR)/u-boot/spl/u-boot-spl.bin
	cp -f -- "$<" "$@"

$(BUILD_DIR)/u-boot.bin: $(BUILD_DIR)/u-boot/u-boot.bin
	cp -f -- "$<" "$@"

%.gz: %
	gzip -fkn9 "$<"

$(BUILD_DIR)/$(SOC)-$(BOARD).dts.txt: linux
	mkdir -p -- "$(BUILD_DIR)"
	$(CPP) -nostdinc -I src/linux/include -I src/linux/arch \
		-undef -x assembler-with-cpp \
		src/linux/arch/riscv/boot/dts/kendryte/$(SOC)_$(BOARD).dts \
		-o $@

%.dtb: %.dts.txt linux
	$(BUILD_DIR)/linux/scripts/dtc/dtc -I dts -q -O dtb "$<" -o "$@"

$(BUILD_DIR)/ug_u-boot.bin: $(BUILD_DIR)/u-boot/u-boot.bin.gz
	$(BUILD_DIR)/u-boot/tools/mkimage -A riscv -C gzip \
		-O u-boot -T firmware  -a 0 -e 0 -n uboot \
		-d "$<" $@

$(BUILD_DIR)/ulinux.bin: $(FW_PAYLOAD).gz u-boot
	$(BUILD_DIR)/u-boot/tools/mkimage -A riscv -C gzip \
		-O linux -T kernel -a 0 -e 0 -n linux -d "$<" "$@"

$(BUILD_DIR)/%.o: src/%.s
	mkdir -p -- "$(BUILD_DIR)"
	$(CROSS_COMPILE)as -c -o "$@" "$<"

$(BUILD_DIR)/init: $(BUILD_DIR)/init.o
	$(CROSS_COMPILE)ld -static -nostdlib -o "$@" "$^"

$(ROOTFS): Makefile $(BUILD_DIR)/ulinux.bin src/extlinux.conf $(DTB) \
		$(BUILD_DIR)/init
	rm -rf -- "$@" "$@.tmp" "$(BUILD_DIR)/rootfs"
	mkdir -p -- "$(BUILD_DIR)/rootfs/boot/"
	#+fakeroot $(MAKE) -C src/linux O=../../$(BUILD_DIR)/linux \
	#	ARCH=riscv CROSS_COMPILE=$(CROSS_COMPILE) \
	#	INSTALL_PATH=$(BUILD_DIR)/rootfs/boot \
	#	INSTALL_MOD_PATH=$(BUILD_DIR)/rootfs \
	#	install modules_install
	fakeroot install -o root -g root -m 0644 -D $(BUILD_DIR)/ulinux.bin \
		"$(BUILD_DIR)/rootfs/boot/vmlinuz-5.10.4"
	fakeroot install -o root -g root -m 0644 -D src/extlinux.conf \
		"$(BUILD_DIR)/rootfs/boot/extlinux/extlinux.conf"
	fakeroot install -o root -g root -m 0644 -D \
		"$(BUILD_DIR)/$(SOC)-$(BOARD).dtb" \
		"$(BUILD_DIR)/rootfs/boot/dtbs/$(SOC)-$(BOARD).dtb"
	fakeroot install -o root -g root -m 0755 -D \
		"$(BUILD_DIR)/init" "$(BUILD_DIR)/rootfs/sbin/init"
	fakeroot /sbin/mkfs.ext4 -L rootfs -d "$(BUILD_DIR)/rootfs" \
		"$@.tmp" 12M
	mv -f -- "$@.tmp" "$@"

$(BUILD_DIR)/fn_%: $(BUILD_DIR)/%
	./make-k230-firmware -i "$<" -o "$@"

sysimage-sdcard.img: \
		$(BUILD_DIR)/fn_u-boot-spl.bin \
		$(BUILD_DIR)/ug_u-boot.bin \
		$(BUILD_DIR)/rootfs.ext4
	dd bs=1K seek=1024 of=$@.tmp if=$(BUILD_DIR)/fn_u-boot-spl.bin
	dd bs=1K seek=1536 of=$@.tmp if=$(BUILD_DIR)/fn_u-boot-spl.bin
	dd bs=1K seek=2048 of=$@.tmp if=$(BUILD_DIR)/ug_u-boot.bin
	dd bs=1K seek=3072 of=$@.tmp if=$(BUILD_DIR)/rootfs.ext4
	truncate --size=+1M "$@.tmp" # GPT copy
	/sbin/sfdisk "$@.tmp" < src/sdcard.dump
	mv -- "$@.tmp" "$@"

.PHONY: clean
clean:
	git clean -fxd

help:
	@echo "Usage: "
	@echo "make"
	@echo "Supported compilation options"
	@echo "make                          -- Build all for k230";
	@echo "make prepare_sourcecode       -- down source code";
	@echo "make uboot                    -- Build U-boot";
	@echo "make build-image              -- Build k230 rootfs image";
