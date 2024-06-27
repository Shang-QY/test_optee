loopdevice=`sudo losetup --partscan --find --show disk.img`
cd ./linux
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j $(nproc)
cd -
echo $loopdevice
sudo mount ${loopdevice}p1 ./mnt
sudo cp -rf ./linux/arch/riscv/boot/Image ./mnt/boot
sudo cp ./optee_examples/hello_world/host/optee_example_hello_world ./mnt//usr/bin/
sudo umount ./mnt
sudo losetup -D ${loopdevice}

