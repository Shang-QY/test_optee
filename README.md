# Test_OpTee

Download this project
```
git clone https://github.com/yli147/test_optee.git -b tee-debug-nuclei-merge
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
git clone https://github.com/yli147/opensbi.git -b tee-debug-nuclei-merge
cd opensbi
CROSS_COMPILE=riscv64-linux-gnu- make FW_PIC=n PLATFORM=generic
cp build/platform/generic/firmware/fw_dynamic.elf $WORKDIR
```

Compile OPTEE-OS
```
cd $WORKDIR
git clone https://github.com/yli147/optee_os.git -b tee-debug-nuclei-merge
cd optee_os
make CFG_TEE_CORE_LOG_LEVEL=3 CROSS_COMPILE64=riscv64-linux-gnu- ARCH=riscv CFG_RV64_core=y CFG_TZDRAM_START=0xF0C00000 CFG_TZDRAM_SIZE=0x800000 CFG_SHMEM_START=0xFEE00000 CFG_SHMEM_SIZE=0x200000 PLATFORM=nuclei ta-targets=ta_rv64 MARCH=rv64imafdc MABI=lp64d
cp out/riscv-plat-nuclei/core/tee-pager_v2.bin $WORKDIR
riscv64-linux-gnu-objdump -t -S out/riscv-plat-nuclei/core/tee.elf > $WORKDIR/tee.txt
```

Compile OPTEE-client
```
cd $WORKDIR
git clone https://github.com/OP-TEE/optee_client
cd optee_client
mkdir build
cd build
cmake CFG_TEE_CLIENT_LOG_LEVEL=3 CFG_TEE_SUPP_LOG_LEVEL=3 -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
make
make install
```

Compile OPTEE-examples
```
cd $WORKDIR
git clone https://github.com/linaro-swg/optee_examples.git
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
git clone https://github.com/yli147/linux.git -b tee-debug-nuclei-merge
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
