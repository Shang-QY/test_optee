################################################################################
# Following variables defines how the NS_USER (Non Secure User - Client
# Application), NS_KERNEL (Non Secure Kernel), S_KERNEL (Secure Kernel) and
# S_USER (Secure User - TA) are compiled
################################################################################
COMPILE_NS_USER ?= 64
override COMPILE_NS_KERNEL := 64
COMPILE_S_USER ?= 64
COMPILE_S_KERNEL ?= 64

################################################################################
# Override variables in common.mk
################################################################################
ARCH = riscv
ROOT = $(WORKDIR)
NUM_CPUS := $(shell nproc)
nproc = $(shell echo $(NUM_CPUS) - 3 | bc)

QEMU_VIRTFS_AUTOMOUNT = y

BR2_ROOTFS_OVERLAY = $(ROOT)/build/br-ext/board/qemu/overlay
BR2_ROOTFS_POST_BUILD_SCRIPT = $(ROOT)/build/br-ext/board/qemu/post-build.sh
BR2_ROOTFS_POST_SCRIPT_ARGS = "$(QEMU_VIRTFS_AUTOMOUNT) $(QEMU_VIRTFS_MOUNTPOINT) $(QEMU_PSS_AUTOMOUNT)"
BR2_TARGET_GENERIC_GETTY_PORT = $(if $(CFG_NW_CONSOLE_UART),ttyS$(CFG_NW_CONSOLE_UART),ttyS0)
BR2_TARGET_ROOTFS_EXT2 = y

OPTEE_OS_PLATFORM = virt

# optee_test
WITH_TLS_TESTS			= n
WITH_CXX_TESTS			= n

DEBUG = 1

################################################################################
# Paths to git projects and various binaries
################################################################################
OPENSBI_PATH			?= $(ROOT)/opensbi
BUILD_PATH				?= $(ROOT)/build
LINUX_PATH				?= $(ROOT)/linux
UBOOT_PATH				?= $(ROOT)/u-boot
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_EXAMPLES_PATH		?= $(ROOT)/optee_examples
BUILDROOT_PATH			?= $(ROOT)/buildroot
BINARIES_PATH			?= $(ROOT)/out/bin
QEMU_PATH				?= $(ROOT)/qemu
QEMU_BUILD				?= $(QEMU_PATH)/build
MODULE_OUTPUT			?= $(ROOT)/out/kernel_modules

################################################################################
# Targets
################################################################################
TARGET_DEPS := toolchains qemu dtb opensbi optee-os uboot linux buildroot
TARGET_CLEAN := qemu-clean dtb opensbi-clean optee-os-clean uboot-clean linux-clean buildroot-clean

all: $(TARGET_DEPS)

clean: $(TARGET_CLEAN)

$(BINARIES_PATH):
	mkdir -p $@

################################################################################
# Toolchains
################################################################################
SHELL				= /bin/bash
TOOLCHAIN_ROOT 		?= $(ROOT)/toolchains
UNAME_M				:= $(shell uname -m)

# Download toolchain macro for saving some repetition
# $(1) is $AARCH.._PATH		: i.e., path to the destination
# $(2) is $SRC_AARCH.._GCC	: is the downloaded tar.gz file
# $(3) is $.._GCC_VERSION	: the name of the file to download
define dltc
	@if [ ! -d "$(1)" ]; then \
		echo "Downloading $(3) ..."; \
		echo "mkdir $(1) ..."; \
		mkdir -p $(1); \
		cd $(TOOLCHAIN_ROOT); \
		wget -c $(2) || \
			{ rm -f $(3).tar.gz; cd $(TOOLCHAIN_ROOT) && rmdir $(1); echo Download failed; exit 1; }; \
		tar zxvf $(3).tar.gz -C $(1) --strip-components=1 || \
			{ rm $(TOOLCHAIN_ROOT)/$(3).tar.gz; echo Downloaded file is damaged; \
			cd $(TOOLCHAIN_ROOT) && rm -rf $(1); exit 1; }; \
		(cd $(1)/bin && shopt -s nullglob && for f in *-none-linux*; do ln -s $$f $${f//-none} ; done;) \
	fi
endef

RISCV64_PATH 			?= $(TOOLCHAIN_ROOT)/riscv64
RISCV64_CROSS_COMPILE 		?= $(RISCV64_PATH)/bin/riscv64-unknown-linux-gnu-
RISCV64_GCC_RELEASE_DATE	?= 2023.07.07
RISCV64_GCC_VERSION		?= riscv64-glibc-ubuntu-20.04-gcc-nightly-$(RISCV64_GCC_RELEASE_DATE)-nightly
SRC_RISCV64_GCC			?= https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/$(RISCV64_GCC_RELEASE_DATE)/$(RISCV64_GCC_VERSION).tar.gz

.PHONY: toolchains
toolchains: riscv64-toolchain

.PHONY: riscv64-toolchain
riscv64-toolchain:
	$(call dltc,$(RISCV64_PATH),$(SRC_RISCV64_GCC),$(RISCV64_GCC_VERSION))

################################################################################
# QEMU
################################################################################
QEMU_MACHINE	?= virt,aia=aplic-imsic,acpi=off,hmat=on,rpmi=on
QEMU_DTB	?= $(ROOT)/qemu_rv64_virt_domain.dtb

$(QEMU_BUILD)/config-host.mak:
	cd $(QEMU_PATH); ./configure --target-list="riscv64-softmmu"

qemu: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(QEMU_PATH) -j $(nproc)

qemu-clean:
	$(MAKE) -C $(QEMU_PATH) clean

################################################################################
# Device Tree Blob
################################################################################
dtb:
	dtc -I dts -O dtb -o $(QEMU_DTB) $(ROOT)/qemu-virt.dts

dtb-clean:
	rm $(QEMU_DTB)

################################################################################
# openSBI
################################################################################
OPENSBI_EXPORTS ?= \
	CROSS_COMPILE=$(RISCV64_CROSS_COMPILE)

OPENSBI_FLAGS ?= PLATFORM=generic

OPENSBI_OUT = $(OPENSBI_PATH)/build/platform/generic/firmware

.PHONY: opensbi
opensbi:
	$(MAKE) -B opensbi-common

opensbi-common:
	$(OPENSBI_EXPORTS) $(MAKE) -C $(OPENSBI_PATH) $(OPENSBI_FLAGS)
	mkdir -p $(BINARIES_PATH)
	ln -sf $(OPENSBI_OUT)/fw_dynamic.elf $(BINARIES_PATH)

opensbi-clean:
	$(OPENSBI_EXPORTS) $(MAKE) -C $(OPENSBI_PATH) $(OPENSBI_FLAGS) clean
	rm $(BINARIES_PATH)/fw_dynamic.elf

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_BIN	?= $(OPTEE_OS_PATH)/out/riscv-plat-virt/core/tee.bin

OPTEE_OS_COMMON_FLAGS += ARCH=riscv
OPTEE_OS_COMMON_FLAGS += CROSS_COMPILE64=$(RISCV64_CROSS_COMPILE)
OPTEE_OS_COMMON_FLAGS += DEBUG=$(DEBUG)
# OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_NB_CORE=$(QEMU_SMP)
# OPTEE_OS_COMMON_FLAGS += CFG_NUM_THREADS=$(QEMU_SMP)
OPTEE_OS_COMMON_FLAGS += CFG_TEE_CORE_LOG_LEVEL=4
OPTEE_OS_COMMON_FLAGS += CFG_TEE_TA_LOG_LEVEL=4
# OPTEE_OS_COMMON_FLAGS += CFG_UNWIND=y

OPTEE_OS_LOAD_ADDRESS ?= 0xf0c00000

ifeq ($(ARCH),riscv)

ifeq ($(COMPILE_S_USER),32)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/riscv/export-ta_rv32
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_USER_TA_TARGETS=ta_rv32
endif
ifeq ($(COMPILE_S_USER),64)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/riscv/export-ta_rv64
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_USER_TA_TARGETS=ta_rv64
endif

ifeq ($(COMPILE_S_KERNEL),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_RV64_core=y
else
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_RV64_core=n
endif

endif

OPTEE_OS_COMMON_FLAGS += $(OPTEE_OS_COMMON_EXTRA_FLAGS) $(OPTEE_OS_TA_CROSS_COMPILE_FLAGS)
OPTEE_OS_COMMON_FLAGS += MABI=lp64d
OPTEE_OS_COMMON_FLAGS += MARCH=rv64imafdc
OPTEE_OS_COMMON_FLAGS += PLATFORM=virt
OPTEE_OS_COMMON_FLAGS += CFG_DT=n
OPTEE_OS_COMMON_FLAGS += CFG_RPMB_FS=y
OPTEE_OS_COMMON_FLAGS += CFG_RPMB_WRITE_KEY=y
OPTEE_OS_COMMON_FLAGS += CFG_TDDRAM_START=0xF0C00000
OPTEE_OS_COMMON_FLAGS += CFG_TDDRAM_SIZE=0x800000
OPTEE_OS_COMMON_FLAGS += CFG_SHMEM_START=0xF1600000
OPTEE_OS_COMMON_FLAGS += CFG_SHMEM_SIZE=0x200000

optee-os: optee-os-common
	ln -sf $(OPTEE_OS_BIN) $(BINARIES_PATH)

optee-os-clean: optee-os-clean-common

.PHONY: optee-os-common
optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS) -j $(nproc)

.PHONY: optee-os-clean-common
optee-os-clean-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS) clean

.PHONY: optee-os-devkit
optee-os-devkit:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS) ta_dev_kit

################################################################################
# U-Boot
################################################################################
$(UBOOT_PATH)/.config:
	$(MAKE) -C $(UBOOT_PATH) qemu-riscv64_smode_defconfig CROSS_COMPILE=riscv64-linux-gnu-

uboot: $(QEMU_BUILD)/config-host.mak
	$(MAKE) -C $(UBOOT_PATH) CROSS_COMPILE=riscv64-linux-gnu- -j $(nproc)
	mkdir -p $(BINARIES_PATH)
	ln -sf $(UBOOT_PATH)/u-boot.bin $(BINARIES_PATH)

uboot-clean:
	$(MAKE) -C $(UBOOT_PATH) CROSS_COMPILE=riscv64-linux-gnu- clean

################################################################################
# Linux kernel
################################################################################
LINUX_DEFCONFIG_COMMON_ARCH := riscv
LINUX_COMMON_FLAGS += ARCH=riscv -j $(nproc) CROSS_COMPILE=$(RISCV64_CROSS_COMPILE)

linux-defconfig:
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) defconfig

linux: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS)
	mkdir -p $(BINARIES_PATH)
	ln -sf $(LINUX_PATH)/arch/riscv/boot/Image $(BINARIES_PATH)

linux-defconfig-clean: linux-defconfig-clean-common

linux-clean: linux-defconfig-clean-common linux-clean-common

.PHONY: linux-defconfig-clean-common
linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

.PHONY: linux-clean-common
linux-clean-common:
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS) clean

################################################################################
# Buildroot Rootfs, Create Disk
################################################################################
optee_client:
	cd $(OPTEE_CLIENT_PATH)
	mkdir build
	cd build
	cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=$(RISCV64_CROSS_COMPILE)gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr .. clean
	cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=$(RISCV64_CROSS_COMPILE)gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
	make
	make install

OPTEE-examples:
	cd $(OPTEE_EXAMPLES_PATH)/hello_world/host
	make CROSS_COMPILE=$(RISCV64_CROSS_COMPILE) TEEC_EXPORT=$(OPTEE_CLIENT_PATH)/build/out/export/usr --no-builtin-variables
	cd $(OPTEE_EXAMPLES_PATH)/hello_world/ta
	make CROSS_COMPILE=$(RISCV64_CROSS_COMPILE) PLATFORM=vexpress-qemu_virt TA_DEV_KIT_DIR=$(OPTEE_OS_PATH)/out/riscv-plat-virt/export-ta_rv64

buildroot-defconfig:
	$(MAKE) -C $(BUILDROOT_PATH) qemu_riscv64_virt_defconfig

buildroot: buildroot-defconfig optee_client optee_examples
	$(MAKE) -C $(BUILDROOT_PATH) -j $(nproc)
	./script/mkdisk.sh
	ln -sf $(ROOT)/disk.img $(BINARIES_PATH)

buildroot-clean:

################################################################################
# Run targets
################################################################################
.PHONY: run
# This target enforces updating root fs etc
run: all
	$(MAKE) run-only

.PHONY: run-only
run-only:
	$(QEMU_BUILD)/qemu-system-riscv64 -d guest_errors -D guest_log.txt \
		-M $(QEMU_MACHINE) \
		-dtb $(QEMU_DTB) \
		-m 4G,slots=2,maxmem=8G -object memory-backend-ram,size=2G,id=m0 -object memory-backend-ram,size=2G,id=m1 \
		-numa node,nodeid=0,memdev=m0 -numa node,nodeid=1,memdev=m1 -smp 2,sockets=2,maxcpus=2 \
		-bios $(BINARIES_PATH)/fw_dynamic.elf \
		-kernel $(BINARIES_PATH)/u-boot.bin \
		-device loader,file=$(BINARIES_PATH)/tee.bin,addr=$(OPTEE_OS_LOAD_ADDRESS) \
		-serial tcp:localhost:54320,server \
		-drive file=$(BINARIES_PATH)/disk.img,if=none,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0 \
		-nographic -device virtio-net-pci,netdev=usernet -netdev user,id=usernet,hostfwd=tcp::9990-:22
