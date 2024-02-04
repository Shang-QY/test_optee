export WORKDIR=`pwd`
cd opensbi
CROSS_COMPILE=riscv64-linux-gnu- make FW_PIC=n PLATFORM=generic
cp build/platform/generic/firmware/fw_dynamic.elf $WORKDIR
riscv64-linux-gnu-objdump -t -S build/platform/generic/firmware/fw_dynamic.elf > $WORKDIR/fw_dynamic.txt
cd $WORKDIR
cd optee_os
make CFG_TEE_CORE_LOG_LEVEL=3 CROSS_COMPILE64=/opt/riscv/bin/riscv64-unknown-linux-gnu- ARCH=riscv CFG_DT=n CFG_RV64_core=y CFG_TDDRAM_START=0xF0C00000 CFG_TDDRAM_SIZE=0x800000 CFG_SHMEM_START=0xF1600000 CFG_SHMEM_SIZE=0x200000 PLATFORM=virt ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d

cp out/riscv-plat-virt/core/tee.bin $WORKDIR/tee-pager_v2.bin
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S out/riscv-plat-virt/core/tee.elf > $WORKDIR/tee.txt
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S out/riscv-plat-virt/ldelf/ldelf.elf > $WORKDIR/ldelf.txt
