
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

export NVRAM=/boot/nvram
export FS="nobootprompt=tcp fs=10.0.2.2 auth=10.0.2.2"

if [ "$DISK" = "" ]; then
	export DISK=$JEHANNE/hacking/sample-disk.img
fi

if [ -f $DISK ]; then
	usbDev="-drive if=none,id=usbstick,file=$DISK -usb -device nec-usb-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=usbstick"
	usbDev="-readconfig /usr/share/doc/qemu-system-x86/common/ich9-ehci-uhci.cfg -drive if=none,id=usbstick,file=$DISK -usb -device usb-storage,bus=ehci.0,drive=usbstick "
fi

if [ "$KERNDIR" = "" ]; then
	KERNDIR=$JEHANNE/arch/$ARCH/kern/
fi
if [ "$KERNEL" = "" ]; then
	KERNEL="jehanne.32bit"
fi
if [ "$NCPU" = "" ]; then
	NCPU=4
fi

QEMU_USER=`whoami`

cd $KERNDIR
read -r cmd <<EOF
$kvmdo qemu-system-x86_64 -s -cpu Haswell -smp $NCPU -m 2048 $kvmflag \
-rtc clock=vm \
-no-reboot -serial mon:stdio \
--machine $machineflag \
$bootDisk \
-netdev user,id=ethernet.0,hostfwd=tcp::5555-:1522,hostfwd=tcp::9999-:9,hostfwd=tcp::17010-:17010,hostfwd=tcp::17013-:17013 \
-device rtl8139,netdev=ethernet.0 \
$usbDev \
-append "maxcores=1024 nvram=$NVRAM nvrlen=512 nvroff=0 console=0 qemu-user=$QEMU_USER *acpi= $FS $KAPPEND" \
-initrd ./initrd \
-kernel $KERNEL $*
EOF

# To enable qemu log:
#-D $JEHANNE/../qemu.log -d int,cpu_reset,in_asm \

#-net dump,file=/tmp/vm0.pcap \

echo $cmd
eval $cmd

kill $ufspid
wait
