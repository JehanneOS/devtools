#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

if [ "$JEHANNE" = "" ]; then
        echo ./hacking/QA.sh requires the shell started by ./hacking/devshell.sh
        exit 1
fi

trap : 2

$JEHANNE/hacking/bin/ufs -d=0 -root=$JEHANNE &
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

if [ "$KERNDIR" = "" ]; then
	KERNDIR=$JEHANNE/arch/$ARCH/kern/
fi
if [ "$KERNEL" = "" ]; then
	KERNEL=jehanne.32bit
fi
if [ "$NCPU" = "" ]; then
	NCPU=1
fi
if [ "$CPU_MODEL" = "" ]; then
	CPU_MODEL=Opteron_G1
fi

QEMU_USER=`whoami`

appendLine="console=0 nobootprompt=tcp maxcores=1024 fs=10.0.2.2 auth=10.0.2.2 nvram=/boot/nvram nvrlen=512 nvroff=0 qemu-user=$QEMU_USER $KAPPEND"
appendLine="-append '$appendLine'"
kernelLine="-kernel $KERNEL $*"
if [ "$DISK" = "" ]; then
	if [ "$QA_DISK" != "" ]; then
		# disk to run QA checks
		export DISK=$QA_DISK
		# will boot from disk, no need for kernel and so on
		appendLine=""
		kernelLine=""
	else
		export DISK=$JEHANNE/hacking/sample-disk.img
	fi
fi

if [ -a $DISK ]; then
	bootDisk="-device ahci,id=ahci -drive id=boot,file=$DISK,index=0,cache=writeback,if=none -device ide-drive,drive=boot,bus=ahci.0"
fi

cd $KERNDIR
read -r cmd <<EOF
$kvmdo qemu-system-x86_64 -s -cpu $CPU_MODEL -smp $NCPU -m 2048 $kvmflag \
-serial stdio \
--nographic \
--monitor /dev/null \
--machine $machineflag \
$bootDisk \
-net nic,model=rtl8139 \
-net user,hostfwd=tcp::5555-:1522 \
-net dump,file=/tmp/vm0.pcap \
-netdev user,id=tcp9,hostfwd=tcp::9999-:9 \
-netdev user,id=tcp17010,hostfwd=tcp::17010-:17010 \
-netdev user,id=tcp17013,hostfwd=tcp::17013-:17013 \
$appendLine $kernelLine
EOF

#-no-reboot -D $JEHANNE/../qemu.log -d int,cpu_reset,in_asm \

echo $cmd
eval $cmd

kill $ufspid
wait

