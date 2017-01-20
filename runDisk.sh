#!/bin/sh

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

export SDL_VIDEO_X11_DGAMOUSE=0 # see https://wiki.archlinux.org/index.php/QEMU#Mouse_cursor_is_jittery_or_erratic

if [ "$JEHANNE" = "" ]; then
        echo $0 requires the shell started by ./hacking/devshell.sh
        exit 1
fi

trap : 2

export machineflag=pc
if [ "$(uname)" = "Linux" ] && [ -e /dev/kvm ]; then
        export kvmflag='-enable-kvm'
        export machineflag='pc,accel=kvm'
        if [ ! -w /dev/kvm ]; then
                # we don't have access as a regular user
                export kvmdo=sudo
        fi
fi

if [ "$1" = "" ]; then
	if [ "$DISK" = "" ]; then
		if [ -f $JEHANNE/hacking/sample-disk.img ]; then
			export DISK=$JEHANNE/hacking/sample-disk.img
		else
			echo No disk image provided: usage: $0 path/to/disk
			exit 1
		fi
	fi
else
	export DISK="$1"
fi

case "$DISK" in
	*:*)
		bootDisk="-usb -usbdevice host:$DISK"
		;;
	*)
		bootDisk="-drive if=none,id=usbstick,file=$DISK -usb -readconfig /usr/share/doc/qemu-system-x86/common/ich9-ehci-uhci.cfg -device usb-host,bus=usb-bus.0,hostbus=3,hostport=1 -device usb-host,bus=usb-bus.0,hostbus=3,hostport=1 -device usb-storage,bus=ehci.0,drive=usbstick "
		;;
esac
#bootDisk="-device ahci,id=ahci -drive id=boot,file=$DISK,index=0,cache=writeback,if=none -device ide-drive,drive=boot,bus=ahci.0"
bootDisk="-global ide-drive.physical_block_size=4096 -drive file=$DISK,if=ide,index=0,media=disk"

if [ "$NCPU" = "" ]; then
	NCPU=2
fi

cd $JEHANNE/arch/$ARCH/kern/
read -r cmd <<EOF
$kvmdo qemu-system-x86_64 -s -cpu Haswell -smp $NCPU -m 2048 $kvmflag \
-no-reboot -serial mon:stdio \
--machine $machineflag \
$bootDisk \
-net nic,model=rtl8139 \
-net user,hostfwd=tcp::5555-:1522 \
-net dump,file=/tmp/vm0.pcap \
-redir tcp:9999::9 \
-redir tcp:17010::17010 \
-redir tcp:17013::17013
EOF

# To enable qemu log:
#-D $JEHANNE/../qemu.log -d int,cpu_reset,in_asm \

echo $cmd
eval $cmd

