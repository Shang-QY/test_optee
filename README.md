# Test_OpTee

Download this project
```
git clone https://github.com/Shang-QY/test_optee.git
cd test_optee
export WORKDIR=`pwd`
<<<<<<< HEAD
=======

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
>>>>>>> main

git submodule update --init --recursive
```

Construct toolchain, qemu, dtb, opensbi, optee-os, uboot, linux, buildroot one by one
```
make toolchains
make qemu
make dtb
make opensbi
make optee-os
make uboot
make linux
make buildroot

OR
make all
```

## Run
```
<<<<<<< HEAD
make run-only
```

launch another terminal and connect to normal world
=======
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
>>>>>>> main
```
telnet localhost 54320

# log in with `root`, and run example
optee_example_hello_world
```
<<<<<<< HEAD
=======
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

>>>>>>> main
