#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

if [ "$JEHANNE" = "" ]; then
	echo $0 requires the shell started by ./hacking/devshell.sh
	exit 1
fi

if [ "$SYSLINUXBIOS" == "" ]; then
	export SYSLINUXBIOS=/usr/lib/syslinux/modules/bios/ # GNU/Linux Debian way
fi
if [ ! -d "$SYSLINUXBIOS" ]; then
	echo 'Missing $SYSLINUXBIOS: install syslinux-utils or set it to the proper path.'
	exit 1
fi

if [ -d $JEHANNE/hacking/disk-setup/bios/ ]; then
	rm $JEHANNE/hacking/disk-setup/bios/*
else
	mkdir $JEHANNE/hacking/disk-setup/bios/
fi
cp $SYSLINUXBIOS/lib* $JEHANNE/hacking/disk-setup/bios/
cp $SYSLINUXBIOS/elf.c32 $JEHANNE/hacking/disk-setup/bios/
cp $SYSLINUXBIOS/mboot.c32 $JEHANNE/hacking/disk-setup/bios/
cp $SYSLINUXBIOS/menu.c32 $JEHANNE/hacking/disk-setup/bios/

# Create the data disk
if [ "$DISK" == "" ]; then
	export DISK=$JEHANNE/hacking/sample-disk.img
fi


if [ ! -f $DISK ]; then
	qemu-img create $DISK 4G

	sed -e 's/^\s*\([\+0-9a-zA-Z]*\)[ ].*/\1/' << EOF | /sbin/fdisk $DISK
    o     #clear partition table
    n     #new partition
    p     #primary partition
    1     #partition 1
          #start at beginning of disk
    +40M  #reserve 40 megabytes
    t     #change type
    c     #W95 FAT32 (LBA)
    a     #make it bootable
    n     #new partition
    p     #primary partition
    2     #partition 2
          #start at first free sector
          #end at the end of disk
    t     #change type
    2     #partition 2
    39    #Plan 9
    p     #print partition table
    w     #write partition table
    q     #quit
EOF

export KERNEL=$JEHANNE/hacking/bin/workhorse.32bit
export KERNDIR=$JEHANNE/hacking/bin/

if [ "$DISK_KERNEL" = "" ]; then
	export DISK_KERNEL=/arch/$ARCH/kern/jehanne.32bit
fi
if [ "$DISK_INITRD" = "" ]; then
	export DISK_INITRD=/arch/amd64/kern/initrd
fi

	# install everything
	cat << EOF | runqemu
disk/fdisk -p /dev/sdE0/data >> /dev/sdE0/ctl
disk/prep -w -a nvram -a fs /dev/sdE0/plan9
disk/prep -p /dev/sdE0/plan9 >> /dev/sdE0/ctl
cat /dev/sdE0/ctl

disk/format -d /dev/sdE0/dos /hacking/disk-setup/syslinux.cfg /hacking/disk-setup/bios/* $DISK_INITRD $DISK_KERNEL

dd -if /hacking/nvram -of /dev/sdE0/nvram

hjfs -n hjfs -Srf /dev/sdE0/fs
/hacking/disk-setup/configure-hjfs >>/srv/hjfs.cmd
hjfs -n hjfs -Sf /dev/sdE0/fs
mount -c /srv/hjfs /n/newfs
cd /n/newfs
cd cfg
dircp /root/cfg .
cd /n/newfs
mkdir arch
cd arch
dircp /root/arch .
cd /n/newfs
mkdir lib
cd lib
dircp /root/lib .
cd /n/newfs
mkdir mnt
cd mnt
mkdir temp
mkdir term
mkdir acme
mkdir wsys
cd /n/newfs
mkdir usr
cd usr
dircp /root/usr .
cd /n/newfs
mkdir sys
cd sys
mkdir include
mkdir src
dircp /root/sys/src src/
dircp /root/sys/include include/
mkdir log
cd /n/newfs
mkdir qa
cd qa
dircp /root/qa .
cd /n/newfs
lc
$AFTER_DISK_FILL
unmount /n/newfs
echo df >> /srv/hjfs.cmd
echo sync >> /srv/hjfs.cmd
sleep 60
echo halt >> /srv/hjfs.cmd
sleep 20
EOF
	syslinux --offset $((2048*512)) $DISK
	dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/mbr.bin of=$DISK
else
	echo Root disk already exists: $DISK
fi

