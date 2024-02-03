# Test_OpTee

Download this project
```
git clone https://github.com/Shang-QY/test_optee.git
cd test_optee
export WORKDIR=`pwd`

git submodule update --init --recursive
```

Compile QEMU
```
cd qemu
./configure --target-list=riscv64-softmmu
make -j $(nproc)
```

Compile OpenSBI

```
cd opensbi
CROSS_COMPILE=riscv64-linux-gnu- make FW_PIC=n PLATFORM=generic
cp build/platform/generic/firmware/fw_dynamic.elf $WORKDIR
```

Compile OPTEE-OS
```
cd optee_os
make CROSS_COMPILE64=riscv64-linux-gnu- ARCH=riscv CFG_RV64_core=y CFG_TZDRAM_START=0xF0C00000 CFG_TZDRAM_SIZE=0x800000 CFG_SHMEM_START=0xFEE00000 CFG_SHMEM_SIZE=0x200000 PLATFORM=nuclei ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-nuclei/core/tee-pager_v2.bin $WORKDIR
riscv64-linux-gnu-objdump -t -S out/riscv-plat-nuclei/core/tee.elf > $WORKDIR/tee.txt
```

Compile OPTEE-client
```
cd optee_client
mkdir build
cd build
cmake -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
make
make install
```

Compile OPTEE-examples
```
cd optee_examples/hello_world/host
make \
    CROSS_COMPILE=riscv64-linux-gnu- \
    TEEC_EXPORT=$WORKDIR/optee_client/build/out/export/usr \
    --no-builtin-variables

cd $WORKDIR	
cd optee_examples/hello_world/ta
make \
    CROSS_COMPILE=riscv64-linux-gnu- \
    PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR=$WORKDIR/optee_os/out/riscv-plat-nuclei/export-ta_rv64
```

Generate DTB
```
cd $WORKDIR
dtc -I dts -O dtb -o qemu-virt-new.dtb ./qemu-virt.dts

OR
./qemu/build/qemu-system-riscv64 -d guest_errors -D guest_log.txt \
    -M virt,aia=aplic-imsic,acpi=off,hmat=on,rpmi=on,dumpdtb=qemu-virt.dtb \
    -m 4G,slots=2,maxmem=8G -object memory-backend-ram,size=2G,id=m0 -object memory-backend-ram,size=2G,id=m1 \
    -numa node,nodeid=0,memdev=m0 -numa node,nodeid=1,memdev=m1 -smp 2,sockets=2,maxcpus=2 \
    -bios ./fw_dynamic.elf \
    -kernel ./u-boot/u-boot.bin \
    -device loader,file=tee-pager_v2.bin,addr=0xF0C00000 \
    -drive file=fat:rw:~/src/fat,id=hd0 -device virtio-blk-device,drive=hd0 \
    -nographic
dtc -I dtb -O dts -o qemu-virt-new.dts ./qemu-virt.dtb
** Manually modify qemu-virt-new.dts **
dtc -I dts -O dtb -o qemu-virt-new.dtb ./qemu-virt-new.dts
```

Compile U-Boot
```
cd u-boot
make qemu-riscv64_smode_defconfig CROSS_COMPILE=riscv64-linux-gnu-
make -j$(nproc) CROSS_COMPILE=riscv64-linux-gnu-
cp u-boot.bin $WORKDIR
```

Compile Linux
```
cd linux
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j $(nproc)
ls arch/riscv/boot -lSh
```

Compile Rootfs
```
cd buildroot
make qemu_riscv64_virt_defconfig
make -j $(nproc)
ls ./output/images/rootfs.ext2
```

Create Disk Image
```
sudo ./mkdisk.sh
```

Run u-boot only
```
cd $WORKDIR
./run-term.sh
```

Run u-boot debugging
```
cd $WORKDIR
Terminal 1 (Need GUI):
./run-term-gdb.sh
Terminal 2:
./gdb-multiarch -x gdbscripts
```

Run u-boot + linux (Need GUI):
```
cd $WORKDIR
./run-linux.sh
```

