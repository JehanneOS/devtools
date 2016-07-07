#!/bin/sh

export SDL_VIDEO_X11_DGAMOUSE=0 # see https://wiki.archlinux.org/index.php/QEMU#Mouse_cursor_is_jittery_or_erratic

if [ "$JEHANNE" = "" ]; then
        echo $0 newdisk.sh requires the shell started by ./hacking/devshell.sh
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
	else
		echo No disk image provided: usage: $0 path/to/disk
		exit 1
	fi
else
	export DISK="$1"
fi

bootDisk="-device ahci,id=ahci -drive id=boot,file=$DISK,index=0,cache=writeback,if=none -device ide-drive,drive=boot,bus=ahci.0"

cd $JEHANNE/arch/$ARCH/kern/
read -r cmd <<EOF
$kvmdo qemu-system-x86_64 -s -cpu Haswell -smp 1 -m 2048 $kvmflag \
-serial stdio \
--machine $machineflag \
$bootDisk \
-net nic,model=rtl8139 \
-net user,hostfwd=tcp::5555-:1522 \
-net dump,file=/tmp/vm0.pcap \
-redir tcp:9999::9 \
-redir tcp:17010::17010 \
-redir tcp:17013::17013 $*
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

