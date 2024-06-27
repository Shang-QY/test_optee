./qemu/build/qemu-system-riscv64 -d guest_errors -D guest_log.txt \
    -M virt,aia=aplic-imsic,acpi=off,hmat=on,rpmi=on \
    -dtb ./qemu-virt-new.dtb \
    -m 4G,slots=2,maxmem=8G -object memory-backend-ram,size=2G,id=m0 -object memory-backend-ram,size=2G,id=m1 \
    -numa node,nodeid=0,memdev=m0 -numa node,nodeid=1,memdev=m1 -smp 2,sockets=2,maxcpus=2 \
    -bios ./fw_dynamic.elf \
    -kernel ./u-boot/u-boot.bin \
    -device loader,file=tee-pager_v2.bin,addr=0xF0C00000 \
    -drive file=fat:rw:~/src/fat,id=hd0 -device virtio-blk-device,drive=hd0 \
    -nographic -s -S
