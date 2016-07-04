#!/bin/bash

if [ "$JEHANNE" = "" ]; then
	echo ./hacking/disk-create.sh requires the shell started by ./hacking/devshell.sh
	exit 1
fi

# Create the boot disk
if [ "$BOOT" == "" ]; then
	export BOOT=$JEHANNE/hacking/sample-boot.img
fi


if [ "$SYSLINUXBIOS" == "" ]; then
	export SYSLINUXBIOS=/usr/lib/syslinux/modules/bios/ # GNU/Linux Debian way
fi
if [ ! -d "$SYSLINUXBIOS" ]; then
	echo 'Missing $SYSLINUXBIOS: install syslinux-utils or set it to the proper path.'
	exit 1
fi

if [ ! -f $BOOT ]; then
	qemu-img create $BOOT 40M

	sed -e 's/^\s*\([\+0-9a-zA-Z]*\)[ ].*/\1/' << EOF | /sbin/fdisk $BOOT
    o     #clear partition table
    n     #new partition
    p     #primary partition
    1     #partition 1
          #start at beginning of disk
          #end at the end of disk
    t     #change type
    c     #W95 FAT32 (LBA)
    a     #make it bootable
    p     #print partition table
    w     #write partition table
    q     #quit
EOF
	/sbin/mkdosfs $BOOT
	syslinux $BOOT

if [ -d $JEHANNE/hacking/disk-setup/bios/ ]; then
	rm $JEHANNE/hacking/disk-setup/bios/*
else
	mkdir $JEHANNE/hacking/disk-setup/bios/
fi
	cp $SYSLINUXBIOS/lib* $JEHANNE/hacking/disk-setup/bios/
	cp $SYSLINUXBIOS/elf.c32 $JEHANNE/hacking/disk-setup/bios/
	cp $SYSLINUXBIOS/mboot.c32 $JEHANNE/hacking/disk-setup/bios/

	cat << EOF | runqemu
dossrv -f /dev/sdE0/data
mkdir dos/
mount -ac '#s/dos' dos/
cp /arch/amd64/kern/jehanne.32bit dos/
cp /hacking/disk-setup/syslinux.cfg dos/
cp /hacking/disk-setup/bios/* dos/
du dos/
unmount dos/
rm -r dos/
EOF

else
	echo Boot disk already exists: $BOOT
fi

# Create the data disk
if [ "$DISK" == "" ]; then
	export DISK=$JEHANNE/hacking/sample-disk.img
fi

if [ ! -f $DISK ]; then
	qemu-img create $DISK 3G

	sed -e 's/^\s*\([\+0-9a-zA-Z]*\)[ ].*/\1/' << EOF | /sbin/fdisk $DISK
    o     #clear partition table
    n     #new partition
    p     #primary partition
    1     #partition 1
          #start at beginning of disk
          #end at the end of disk
    t     #change type
    39    #Plan 9
    p     #print partition table
    w     #write partition table
    q     #quit
EOF

	# install everything
	cat << EOF | runqemu
disk/fdisk -aw /dev/sdE1/data
disk/fdisk -p /dev/sdE1/data
disk/prep -w -a nvram -a fs /dev/sdE1/plan9
hjfs -n hjfs -Srf /dev/sdE1/fs
/hacking/disk-setup/configure-hjfs >>/srv/hjfs.cmd
mount -c /srv/hjfs /n/newfs
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
dircp /root/mnt .
cd /n/newfs
mkdir usr
cd usr
dircp /root/usr .
cd /n/newfs
mkdir sys
cd sys
mkdir include
mkdir src
dircp /root/sys/include include/
dircp /root/sys/src src/
mkdir log
cd /n/newfs
lc
EOF

else
	echo Root disk already exists: $DISK
fi

