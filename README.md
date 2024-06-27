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
git clone https://github.com/yli147/test_optee.git -b dev-rpxy-optee-v3
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
git clone https://github.com/yli147/opensbi.git -b dev-rpxy-optee-v3
cd opensbi
CROSS_COMPILE=riscv64-linux-gnu- make FW_PIC=n PLATFORM=generic
cp build/platform/generic/firmware/fw_dynamic.elf $WORKDIR
```

Compile OPTEE-OS
```
cd $WORKDIR
git clone https://github.com/yli147/optee_os.git -b dev-rpxy-optee-v3
cd optee_os
make CFG_TEE_CORE_LOG_LEVEL=3 CROSS_COMPILE64=/opt/riscv/bin/riscv64-unknown-linux-gnu- ARCH=riscv CFG_DT=n CFG_RPMB_FS=y CFG_RPMB_WRITE_KEY=y CFG_RV64_core=y CFG_TDDRAM_START=0xF0C00000 CFG_TDDRAM_SIZE=0x800000 CFG_SHMEM_START=0xF1600000 CFG_SHMEM_SIZE=0x200000 PLATFORM=virt ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-virt/core/tee.bin $WORKDIR/tee-pager_v2.bin
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S out/riscv-plat-virt/core/tee.elf > $WORKDIR/tee.txt
/opt/riscv/bin/riscv64-unknown-linux-gnu-objdump -t -S out/riscv-plat-virt/ldelf/ldelf.elf > $WORKDIR/ldelf.txt
```

Compile OPTEE-client
```
cd $WORKDIR
git clone https://github.com/OP-TEE/optee_client
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
cd $WORKDIR
git clone https://github.com/linaro-swg/optee_examples.git
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

Compile OPTEE-test
```
cd $WORKDIR
git clone https://github.com/OP-TEE/optee_test.git
optee_test_srcdir := $(srcdir)/optee/optee_test
optee_test_wrkdir := $(wrkdir)/optee/optee_test
optee_test_xtest := $(optee_test_wrkdir)/xtest/xtest
optee_test_tadir := $(optee_test_wrkdir)/ta
optee_test_plugindir := $(optee_test_wrkdir)/supp_plugin

make -C $optee_test_srcdir O=$(optee_test_wrkdir) CROSS_COMPILE=$(CROSS_COMPILE) OPTEE_CLIENT_EXPORT=$(optee_client_export) \
	--no-builtin-variables TA_DEV_KIT_DIR=$(optee_os_export) MARCH=$(ISA) MABI=$(ABI)
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
cd $WORKDIR
git clone https://github.com/u-boot/u-boot.git
cd u-boot
git checkout v2023.10
make qemu-riscv64_smode_defconfig CROSS_COMPILE=riscv64-linux-gnu-
make -j$(nproc) CROSS_COMPILE=riscv64-linux-gnu-
cp u-boot.bin $WORKDIR
```

Compile Linux
```
cd $WORKDIR
git clone https://github.com/yli147/linux.git -b dev-rpxy-optee-v3
cd linux
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j $(nproc)
ls arch/riscv/boot -lSh
```

Compile Rootfs
```
cd $WORKDIR
git clone https://github.com/buildroot/buildroot.git -b 2023.08.x
cd buildroot
make qemu_riscv64_virt_defconfig
make -j $(nproc)
ls ./output/images/rootfs.ext2
```

Create Disk Image
```
cd $WORKDIR
dd if=/dev/zero of=disk.img bs=1M count=128
sudo sgdisk -g --clear --set-alignment=1 \
       --new=1:34:-0:    --change-name=1:'rootfs'    --attributes=3:set:2 \
	   disk.img
loopdevice=`sudo losetup --partscan --find --show disk.img`
echo $loopdevice
sudo mkfs.ext4 ${loopdevice}p1
sudo e2label ${loopdevice}p1 rootfs
mkdir -p mnt
sudo mount ${loopdevice}p1 ./mnt
sudo tar vxf buildroot/output/images/rootfs.tar -C ./mnt --strip-components=1
sudo mkdir ./mnt/boot
sudo cp -rf linux/arch/riscv/boot/Image ./mnt/boot
version=`cat linux/include/config/kernel.release`
echo $version

sudo mkdir -p .//mnt/boot/extlinux
cat << EOF | sudo tee .//mnt/boot/extlinux/extlinux.conf
menu title QEMU Boot Options
timeout 100
default kernel-$version

label kernel-$version
        menu label Linux kernel-$version
        kernel /boot/Image
        append root=/dev/vda1 ro earlycon console=ttyS0,115200n8

label recovery-kernel-$version
        menu label Linux kernel-$version (recovery mode)
        kernel /boot/Image
        append root=/dev/vda1 ro earlycon single
EOF

wget -c https://raw.githubusercontent.com/Nuclei-Software/nuclei-linux-sdk/feature/optee_5.10/conf/evalsoc/S30optee
sudo cp S30optee ./mnt/etc/init.d/
sudo chmod a+x ./mnt/etc/init.d/S30optee
sudo cp -rf ./optee_client/build/out/export/usr/* ./mnt/usr/
sudo mkdir -p ./mnt/lib/optee_armtz
sudo cp ./optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta ./mnt/lib/optee_armtz/
sudo cp ./optee_examples/hello_world/host/optee_example_hello_world ./mnt/usr/bin/

sudo umount ./mnt
sudo losetup -D ${loopdevice}
```

![image](https://github.com/yli147/test_optee/assets/21300636/5cace914-0a82-404e-b106-fb148686f8ff)

![image](https://github.com/yli147/test_optee/assets/21300636/6e204e84-fae7-448b-824d-b610ad783339)


Run u-boot + linux (Need GUI):
```
cd $WORKDIR
./run-linux.sh
```

After Login, execute 
```
optee_example_hello_world
```
