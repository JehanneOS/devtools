#!/bin/bash

if [ "$JEHANNE" = "" ]; then
        echo ./hacking/QA.sh requires the shell started by ./hacking/devshell.sh
        exit 1
fi

trap : 2

$JEHANNE/hacking/bin/ufs -root=$JEHANNE &
ufspid=$!

export machineflag=pc
if [ "$(uname)" = "Linux" ] && [ -e /dev/kvm ]; then
        export kvmflag='-enable-kvm'
        export machineflag='pc,accel=kvm'
        if [ ! -w /dev/kvm ]; then
                # we don't have access as a regular user
                export kvmdo=sudo
        fi
fi

if [ "$DISK" = "" ]; then
	export DISK=$JEHANNE/hacking/sample-disk.img
fi

if [ -f $DISK ]; then
	bootDisk="-device ahci,id=ahci -drive id=boot,file=$DISK,index=0,cache=writeback,if=none -device ide-drive,drive=boot,bus=ahci.0"
fi

cd $JEHANNE/arch/$ARCH/kern/
read -r cmd <<EOF
$kvmdo qemu-system-x86_64 -s -cpu Opteron_G1 -smp 1 -m 2048 $kvmflag \
-serial stdio \
--nographic \
--monitor /dev/null \
--machine $machineflag \
$bootDisk \
-net nic,model=rtl8139 \
-net user,hostfwd=tcp::5555-:1522 \
-net dump,file=/tmp/vm0.pcap \
-redir tcp:9999::9 \
-redir tcp:17010::17010 \
-redir tcp:17013::17013 \
-append "nobootprompt=tcp maxcores=1024 fs=10.0.2.2 auth=10.0.2.2 nvram=/boot/nvram nvrlen=512 nvroff=0" \
-kernel jehanne.32bit $*
EOF

echo $cmd
eval $cmd

kill $ufspid
wait

