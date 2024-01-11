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
make CROSS_COMPILE64=riscv64-linux-gnu- ARCH=riscv CFG_RV64_core=y CFG_TZDRAM_START=0xF0C00000 CFG_TZDRAM_SIZE=0x800000 CFG_SHMEM_START=0xFEE00000 CFG_SHMEM_SIZE=0x200000 PLATFORM=nuclei ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
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

Compile Linux
```
cd $WORKDIR
git clone https://github.com/ventanamicro/linux.git -b dev-upstream
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
        append root=/dev/vda1 ro earlycon

label recovery-kernel-$version
        menu label Linux kernel-$version (recovery mode)
        kernel /boot/Image
        append root=/dev/vda1 ro earlycon single
EOF

sudo umount ./mnt
sudo losetup -D ${loopdevice}
```

![image](https://github.com/yli147/test_optee/assets/21300636/5cace914-0a82-404e-b106-fb148686f8ff)

![image](https://github.com/yli147/test_optee/assets/21300636/6e204e84-fae7-448b-824d-b610ad783339)


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

Run u-boot + linux
```
cd $WORKDIR
./run-term-linux.sh
```

Run u-boot + linux debugging
```
cd $WORKDIR
Terminal 1 (Need GUI):
./run-term-linux-gdb.sh
Terminal 2:
./gdb-multiarch -x gdbscripts
```
