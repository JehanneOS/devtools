#!/bin/sh

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
	bootDisk="-device ahci,id=ahci -drive id=boot,file=$DISK,index=0,cache=writeback,if=none -device ide-drive,drive=boot,bus=ahci.0"
	NVRAM="#S/sdE0/nvram"
#	FS="nobootprompt=local!#S/sdE0" # if you want to boot from disk use runDisk.sh
fi

#usbDev="-usb -usbdevice host:0781:557d"
#usbDev="-usb -usbdevice disk:$JEHANNE/hacking/sample-disk.img"

export NVRAM=/boot/nvram
export FS="nobootprompt=tcp fs=10.0.2.2 auth=10.0.2.2"

cd $JEHANNE/arch/$ARCH/kern/
read -r cmd <<EOF
$kvmdo qemu-system-x86_64 -s -cpu Haswell -smp 1 -m 2048 $kvmflag \
--machine $machineflag \
$bootDisk \
-net nic,model=rtl8139 \
-net user,hostfwd=tcp::5555-:1522 \
-net dump,file=/tmp/vm0.pcap \
-redir tcp:9999::9 \
-redir tcp:17010::17010 \
-redir tcp:17013::17013 \
$usbDev \
-append "maxcores=1024 nvram=$NVRAM nvrlen=512 nvroff=0 $FS" \
-kernel jehanne.32bit $*
EOF

# To enable qemu log:
#-no-reboot -D $JEHANNE/../qemu.log -d int,cpu_reset,in_asm \

# To wait for a gdb connection prepend to -append "waitgdb"
# then from gdb:
#     (gdb) target remote :1234
#     (gdb) p at=1
# now you can set your breakpoints and continue

echo $cmd
eval $cmd

kill $ufspid
wait

