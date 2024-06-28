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

# wget -c https://raw.githubusercontent.com/Nuclei-Software/nuclei-linux-sdk/feature/optee_5.10/conf/evalsoc/S30optee
sudo cp S30optee ./mnt/etc/init.d/
sudo cp -rf ./optee_client/build/out/export/usr/* ./mnt/usr/

sudo cp optee_examples/hello_world/host/optee_example_hello_world mnt/usr/bin
sudo mkdir -p mnt/lib/optee_armtz/
sudo cp -af optee_examples/hello_world/ta/*.ta mnt/lib/optee_armtz/

sudo umount ./mnt
sudo losetup -D ${loopdevice}
