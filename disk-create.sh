#!/bin/bash

if [ "$JEHANNE" == "" ]; then
	echo ./hacking/newdisk.sh requires the shell started by ./hacking/devshell.sh
	exit 1
fi

# Create the boot disk
if [ "$BOOT" == "" ]; then
	BOOT=$JEHANNE/hacking/sample-boot.img
fi

SYSLINUXBIOS=/usr/lib/syslinux/modules/bios/ # GNU/Linux Debian way
if [ ! -d "$SYSLINUXBIOS" ]; then
	echo "Missing $SYSLINUXBIOS" # TODO make me configurable
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

	rm $JEHANNE/hacking/disk-setup/bios/*
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

fi

# Create the data disk
DISK=$JEHANNE/hacking/sample-disk.img
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
disk/prep -w -a^(nvram fossil arenas bloom isect) /dev/sdE1/plan9
venti/fmtarenas arenas0 /dev/sdE1/arenas
venti/fmtisect isect0 /dev/sdE1/isect
venti/fmtindex /hacking/disk-setup/venti.conf
venti/conf -w /dev/sdE1/arenas < /hacking/disk-setup/venti.conf
venti/venti -c /dev/sdE1/arenas
venti=127.0.0.1
fossil/flfmt /dev/sdE1/fossil
echo status \$status
fossil/conf -w /dev/sdE1/fossil /hacking/disk-setup/flproto
echo status \$status
fossil/fossil -f /dev/sdE1/fossil
fossil/fossil -c 'fsys main config /dev/sdE1/fossil' -c 'fsys main open -AWP' -c 'fsys main create /active/adm adm sys d775' -c 'fsys main create /active/adm/users adm sys 664' -c 'users -w'
mount -c /srv/fossil /n/fossil
cd /n/fossil
mkdir arch
cd arch
dircp /root/arch .
cd /n/fossil
mkdir lib
cd lib
dircp /root/lib .
cd /n/fossil
mkdir mnt
cd mnt
dircp /root/mnt .
cd /n/fossil
mkdir usr
cd usr
dircp /root/usr .
cd /n/fossil
mkdir sys
cd sys
mkdir include
mkdir src
dircp /root/sys/include include/
dircp /root/sys/src src/
mkdir log
cd /n/fossil
mkdir rc
cd rc
dircp /root/rc .
fossil/fossil -c 'fsys main config /dev/sdE1/fossil' -c 'fsys main open -AWP' -c 'fsys main snap -a'
EOF

fi

