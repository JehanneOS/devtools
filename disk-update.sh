#!/bin/bash

if [ "$JEHANNE" = "" ]; then
	echo $0 requires the shell started by ./hacking/devshell.sh
	exit 1
fi

if [ "$DISK" == "" ]; then
	export DISK=$JEHANNE/hacking/sample-disk.img
fi

if [ ! -f $DISK ] && [ ! -b $DISK ]; then
	echo "Cannot find DISK to update ($DISK): set the DISK variable"
	exit 1
fi

export KERNEL=$JEHANNE/hacking/bin/workhorse.32bit
export KERNDIR=$JEHANNE/hacking/bin/

# install everything
cat > $JEHANNE/tmp/files.list << EOF
disk/fdisk -p /dev/sdE0/data >> /dev/sdE0/ctl
disk/prep -p /dev/sdE0/plan9 >> /dev/sdE0/ctl
cat /dev/sdE0/ctl

hjfs -n hjfs -Sf /dev/sdE0/fs
mount -c /srv/hjfs /n/newfs

EOF

for var in "$@"
do
    echo "cp /$var /n/newfs/$var" >> $JEHANNE/tmp/files.list
done

cat >> $JEHANNE/tmp/files.list << EOF

unmount /n/newfs
echo df >> /srv/hjfs.cmd
echo sync >> /srv/hjfs.cmd
sleep 60
echo halt >> /srv/hjfs.cmd
sleep 20

EOF

cat $JEHANNE/tmp/files.list | runqemu
rm $JEHANNE/tmp/files.list
