export WORKDIR=`pwd`
loopdevice=`sudo losetup --partscan --find --show disk.img`
cd ./optee_client/build
cmake -DCMAKE_C_COMPILER=/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc -DCMAKE_INSTALL_PREFIX=./out/export/usr ..
make clean
make
make install
cd -
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
echo $loopdevice
sudo mount ${loopdevice}p1 ./mnt
sudo cp -rf ./optee_client/build/out/export/usr/* ./mnt/usr/
sudo cp ./optee_examples/hello_world/host/optee_example_hello_world ./mnt//usr/bin/
sudo mkdir -p ./mnt/lib/optee_armtz
sudo cp ./optee_examples/hello_world/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta ./mnt/lib/optee_armtz/
sudo umount ./mnt
sudo losetup -D ${loopdevice}

