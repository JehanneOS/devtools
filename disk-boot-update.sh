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

# Locate the disk
if [ "$DISK" == "" ]; then
	export DISK=$JEHANNE/hacking/sample-disk.img
fi

if [ ! -b $DISK ] && [ ! -f $DISK ]; then
	echo "Cannot find DISK to update ($DISK): set the DISK variable"
	exit 1
fi

export KERNEL=$JEHANNE/hacking/bin/workhorse.32bit
export KERNDIR=$JEHANNE/hacking/bin/

# install everything
cat << EOF | runqemu
disk/fdisk -p /dev/sdE0/data >> /dev/sdE0/ctl
disk/prep -p /dev/sdE0/plan9 >> /dev/sdE0/ctl
cat /dev/sdE0/ctl

disk/format -d /dev/sdE0/dos /hacking/disk-setup/syslinux.cfg /hacking/disk-setup/bios/* /arch/amd64/kern/initrd /arch/amd64/kern/jehanne.32bit

EOF
syslinux --offset $((2048*512)) $DISK
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/mbr.bin of=$DISK

