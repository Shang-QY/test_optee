# Test_OpTee

Download this project
```
git clone https://github.com/yli147/test_optee.git
cd test_optee
export WORKDIR=`pwd`
```

Compile QEMU
```
cd $WORKDIR
git clone https://github.com/yli147/qemu.git -b dev-standalonemm-rpmi
cd qemu
./configure --target-list=riscv64-softmmu
make -j $(nproc)
```

Compile OpenSBI

```
cd $WORKDIR
git clone https://github.com/yli147/opensbi.git -b tee-debug-v2
cd opensbi
CROSS_COMPILE=riscv64-linux-gnu- make FW_PIC=n PLATFORM=generic
cp build/platform/generic/firmware/fw_dynamic.elf $WORKDIR
```

Compile OPTEE
```
cd $WORKDIR
git clone https://github.com/yli147/optee_os.git -b nuclei/3.18_dev optee_os
cd optee_os
make CROSS_COMPILE64=riscv64-linux-gnu- ARCH=riscv CFG_RV64_core=y CFG_TZDRAM_START=0x80C00000 CFG_TZDRAM_SIZE=0x800000 CFG_SHMEM_START=0xFEE00000 CFG_SHMEM_SIZE=0x200000 PLATFORM=nuclei ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-nuclei/core/tee-pager_v2.bin $WORKDIR
riscv64-linux-gnu-objdump -t -S out/riscv-plat-nuclei/core/tee.elf > $WORKDIR/tee.txt
```

Compile U-Boot
```
cd $WORKDIR
git clone https://github.com/u-boot/u-boot.git
cd u-boot
git checkout v2023.10
make qemu-riscv64_smode_defconfig CROSS_COMPILE=riscv64-linux-gnu-
make -j$(nproc) CROSS_COMPILE=riscv64-linux-gnu-
cp u-boot.bin $WORKDIR
```

![image](https://github.com/yli147/test_optee/assets/21300636/5cace914-0a82-404e-b106-fb148686f8ff)

![image](https://github.com/yli147/test_optee/assets/21300636/6e204e84-fae7-448b-824d-b610ad783339)


Run directly
```
cd $WORKDIR
./run-term.sh
```

GDB Debugging
```
cd $WORKDIR
Terminal 1 (Need GUI):
./run-term-gdb.sh
Terminal 2:
./gdb-multiarch -x gdbscripts
```
