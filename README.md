# Test_OpTee

Download this project
```
git clone https://github.com/Shang-QY/test_optee.git
cd test_optee
export WORKDIR=`pwd`

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
make run-only
```

launch another terminal and connect to normal world
```
telnet localhost 54320

# log in with `root`, and run example
optee_example_hello_world
```
