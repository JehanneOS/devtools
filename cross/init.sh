#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2019 Giacomo Tesio <giacomo@tesio.it>
#
# Jehanne is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2 of the License.
#
# Jehanne is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Jehanne.  If not, see <http://www.gnu.org/licenses/>.

if [ "$JEHANNE" = "" ]; then
        echo $0 requires the shell started by ./hacking/devshell.sh
        exit 1
fi

REPONAME=`basename $JEHANNE`
WORKING_DIR=`dirname $JEHANNE`
WORKING_DIR="$WORKING_DIR/$REPONAME.TOOLCHAIN"
CROSS_DIR="$JEHANNE/hacking/cross"
LOG="$WORKING_DIR/cross.build.log"

function failOnError {
	# $1 -> exit status on a previous command
	# $2 -> task description
	if [ $1 -ne 0 ]; then
		echo "ERROR $2"
		echo
		echo BUILD LOG:
		echo
		cat $LOG
		exit $1
	fi
}

function dynpatch {
	# $1 -> path from $WORKING_DIR/src
	# $2 -> string to search
	( cd $WORKING_DIR/src &&
	  grep -q jehanne $1 ||
	  sed -n -i -e "/$2/r $CROSS_DIR/patch/$1" -e '1x' -e '2,${x;p}' -e '${x;p}' $1
	)
}


# setup Jehanne's headers
usyscalls header $JEHANNE/sys/src/sysconf.json > $JEHANNE/arch/amd64/include/syscalls.h

mkdir -p $WORKING_DIR
date > $LOG

# verify libtool is installed
libtool --version >> $LOG
failOnError $? "libtool installation check"


cp -fpr $JEHANNE/hacking/cross/src $WORKING_DIR
cd $WORKING_DIR/src
fetch >> $LOG
failOnError $? "fetching sources"

mkdir -p $WORKING_DIR/build
rm -f $JEHANNE/hacking/bin/makeinfo
ln -s `which true` $JEHANNE/hacking/bin/makeinfo # don't depend on texinfo
mkdir -p $WORKING_DIR/cross

# Patch and build binutils
echo -n Building binutils...
export BINUTILS_BUILD_DIR=$WORKING_DIR/build/binutils
mkdir -p $BINUTILS_BUILD_DIR

( ( grep -q jehanne $WORKING_DIR/src/binutils/config.sub || (
	cd $WORKING_DIR &&
	sed -i '/jehanne/b; /ELF_TARGET_ID/,/elf_backend_can_gc_sections/s/0x200000/0x1000 \/\/ jehanne hack/g' src/binutils/bfd/elf64-x86-64.c &&
	sed -i '/jehanne/b; s/| midnightbsd\*/| midnightbsd* | jehanne*/g' src/binutils/config.sub &&
	dynpatch 'binutils/bfd/config.bfd' '\# END OF targmatch.h' &&
	dynpatch 'binutils/gas/configure.tgt' '  i386-\*-darwin\*)' &&
	( grep -q jehanne src/binutils/ld/configure.tgt || patch -p1 < $CROSS_DIR/patch/binutils/ld/configure.tgt ) &&
	cp $CROSS_DIR/patch/binutils/ld/emulparams/elf_x86_64_jehanne.sh src/binutils/ld/emulparams/ &&
	cp $CROSS_DIR/patch/binutils/ld/emulparams/elf_i386_jehanne.sh src/binutils/ld/emulparams/ &&
	dynpatch 'binutils/ld/Makefile.am' 'eelf_x86_64.c: ' &&
	(grep 'eelf_i386_jehanne.c \\' src/binutils/ld/Makefile.am || sed -i 's/.*ALL_EMULATION_SOURCES = \\.*/&\n\teelf_i386_jehanne.c \\/' src/binutils/ld/Makefile.am) &&
	(grep 'eelf_x86_64_jehanne.c \\' src/binutils/ld/Makefile.am || sed -i 's/.*ALL_64_EMULATION_SOURCES = \\.*/&\n\teelf_x86_64_jehanne.c \\/' src/binutils/ld/Makefile.am) &&
	cd src/binutils/ld && automake-1.15 && cd ../
	) ) &&
	cd $BINUTILS_BUILD_DIR &&
	$WORKING_DIR/src/binutils/configure --target=x86_64-jehanne --prefix=/posix --with-sysroot=$JEHANNE --target=x86_64-jehanne --enable-interwork --enable-multilib --enable-newlib-long-time_t --disable-nls --disable-werror &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/doc/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/po/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/gas/doc/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/binutils/doc/Makefile.in &&
	make &&
	make DESTDIR=$WORKING_DIR/cross install
) >> $LOG 2>&1
failOnError $? "Building binutils"
echo done.

echo -n Building gcc... | tee -a $WORKING_DIR/gcc.build.log
# Patch and build gcc
export GCC_BUILD_DIR=$WORKING_DIR/build/gcc
mkdir -p $GCC_BUILD_DIR
export CPATH="$WORKING_DIR/cross/posix/lib/gcc/x86_64-jehanne/9.2.0/include:$WORKING_DIR/cross/posix/lib/gcc/x86_64-jehanne/9.2.0/include-fixed"

(
	cd $WORKING_DIR &&
	( grep -q jehanne src/gcc/gcc/config.gcc || patch -p1 < $CROSS_DIR/patch/gcc.patch ) &&
	cp $CROSS_DIR/patch/gcc/gcc/config/jehanne.h src/gcc/gcc/config &&
	sed -i 's/ftp/https/g' src/gcc/contrib/download_prerequisites &&
	cd src &&
	( cd gcc && ./contrib/download_prerequisites ) &&
#	( cd gcc/libstdc++-v3 && autoconf -i ) &&
	cd $GCC_BUILD_DIR &&
	$WORKING_DIR/src/gcc/configure --target=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --enable-languages=c,c++ &&
	make all-gcc all-target-libgcc && 
	make DESTDIR=$WORKING_DIR/cross install-gcc  install-target-libgcc # &&
#	make all-target-libstdc++-v3 &&
#	make DESTDIR=$WORKING_DIR/cross install-target-libstdc++-v3
#	make all-gcc all-target-libgcc && 
#	make DESTDIR=$JEHANNE/pkgs/gcc/9.2.0/ install-gcc install-target-libgcc
#	 &&
#	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true all-target-libstdc++-v3 &&
#	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true install-target-libstdc++-v3
) >> $LOG 2>&1
failOnError $? "building gcc"

echo done.
