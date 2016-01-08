#!/bin/bash

if [ "$JEHANNE" == "" ]; then
	echo ./hacking/newdisk.sh requires the shell started by ./hacking/devshell.sh
	exit 1
fi

# Create the boot disk
BOOT=$JEHANNE/hacking/sample-boot.img
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
    p     #print partition table
    w     #write partition table
    q     #quit
EOF
/sbin/mkdosfs $BOOT
syslinux sample-boot.img

# Create the data disck
DISK=$JEHANNE/hacking/sample-disk.img
qemu-img create $DISK 1G

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
disk/fdisk -aw /dev/sdF0/data
disk/prep -w -a^(nvram fossil arenas bloom isect) /dev/sdF0/plan9
venti/fmtarenas arenas0 /dev/sdF0/arenas
venti/fmtisect isect0 /dev/sdF0/isect
cp /hacking/disk-setup/venti.conf /usr/glenda/venti.conf
venti/fmtindex /usr/glenda/venti.conf
venti/conf -w /dev/sdF0/arenas < /usr/glenda/venti.conf
venti/venti -c /dev/sdF0/arenas
venti=127.0.0.1
fossil/flfmt /dev/sdF0/fossil
cp /hacking/disk-setup/flproto /usr/glenda/flproto
fossil/conf -w /dev/sdF0/fossil < /usr/glenda/flproto
fossil/fossil -f /dev/sdF0/fossil
fossil -c '. /hacking/disk-setup/fossil-init'
mount -c /srv/fossil /n/fossil
cd /n/fossil
mkdir arch
cd arch
dircp /root/arch .
fossil -c '. /hacking/disk-setup/fossil-snapshot'
EOF



