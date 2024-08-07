# Test_OpTee

Download and install toolchain
```
cd /opt/
sudo wget -c https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/2023.07.07/riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz
sudo tar zxvf riscv64-glibc-ubuntu-20.04-gcc-nightly-2023.07.07-nightly.tar.gz
cd -
```

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
```

Compile OPTEE-OS
```
cd optee_os
make CFG_TEE_CORE_LOG_LEVEL=3 CROSS_COMPILE64=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    ARCH=riscv CFG_DT=n CFG_RPMB_FS=y CFG_RPMB_WRITE_KEY=y CFG_RV64_core=y \
    CFG_TDDRAM_START=0xF0C00000 CFG_TDDRAM_SIZE=0x800000 CFG_SHMEM_START=0xF1600000 \
    CFG_SHMEM_SIZE=0x200000 PLATFORM=virt ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-virt/core/tee.bin $WORKDIR/tee-pager_v2.bin
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S out/riscv-plat-virt/core/tee.elf > $WORKDIR/tee.txt
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S out/riscv-plat-virt/ldelf/ldelf.elf > $WORKDIR/ldelf.txt
```

Compile OPTEE-client
```
cd optee_client
mkdir build
cd build
cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr .. clean
cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
make
make install
```

Compile OPTEE-examples
```
cd optee_examples/hello_world/host
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    TEEC_EXPORT=$WORKDIR/optee_client/build/out/export/usr \
    --no-builtin-variables clean
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    TEEC_EXPORT=$WORKDIR/optee_client/build/out/export/usr \
    --no-builtin-variables
cd -
cd optee_examples/hello_world/ta
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR=$WORKDIR/optee_os/out/riscv-plat-virt/export-ta_rv64 clean
make \
    CROSS_COMPILE=/opt/riscv/bin/riscv64-unknown-linux-gnu- \
    PLATFORM=vexpress-qemu_virt \
    TA_DEV_KIT_DIR=$WORKDIR/optee_os/out/riscv-plat-virt/export-ta_rv64
cd -
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S ./optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.elf > $WORKDIR/8aaaf200-2450-11e4-abe2-0002a5d5c51b.txt
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
sudo ./script/mkdisk.sh
```

Run u-boot + linux:
```
Terminal 1:
cd $WORKDIR
./script/run-linux.sh
Terminal 2:
telnet localhost 54320
```

After Login in terminal 2 (user: root), execute 
```
optee_example_hello_world
```
