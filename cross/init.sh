#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016 Giacomo Tesio <giacomo@tesio.it>
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

# setup Jehanne's headers
usyscalls header $JEHANNE/sys/src/sysconf.json > $JEHANNE/arch/amd64/include/syscalls.h

#
# WELLCOME TO HELL ! ! !
#

# If you want to understand _WHY_ Jehanne exists, you should try to
# create a GCC crosscompiler in Debian without requiring root access or Tex.
# And this despite the extreme quality of Debian GNU/Linux!

# fetch all sources
(cd src && fetch)

# To create a Jehanne version of GCC, we need specific OUTDATED versions
# of Autotools that won't compile easily in a modern Linux distro.

function failOnError {
	# $1 -> exit status on a previous command
	# $2 -> task description
	if [ $1 -ne 0 ]; then
		echo "ERROR $2"
		exit $1
	fi
}


# build m4 1.4.14
# - workaround a bug in lib/stdio.in.h, see http://lists.gnu.org/archive/html/bug-m4/2012-08/msg00008.html
# - workaround a bug in src/m4.h, see https://bugs.archlinux.org/task/19829
# both bugs exists thanks to changes in external code
if [ ! -f tmp/bin/m4 ]; then
(
	cd src/m4 &&
	sed -i '/_GL_WARN_ON_USE (gets/d' lib/stdio.in.h &&
	( grep -q '#include <sys/stat.h>'  src/m4.h || sed -i 's:.*\#include <sys/types\.h>.*:&\n#include <sys/stat.h>:g' src/m4.h ) &&
	./configure --prefix=$JEHANNE/hacking/cross/tmp &&
	make && make install
)
failOnError $? "building m4"
fi
# build autoconf 2.64
# - hack git-version-gen to avoid the -dirty flag in version on make
# - autoreconf
# - disable doc build
# - disable man build
if [ ! -f tmp/bin/autoconf ]; then
(
	cd src/autoconf &&
	cp ../../patch/autoconf/build-aux/git-version-gen build-aux/git-version-gen &&
	autoreconf &&
	./configure --prefix=$JEHANNE/hacking/cross/tmp &&
	cp ../../patch/MakeNothing.in ../autoconf/doc/Makefile.in &&
	cp ../../patch/MakeNothing.in ../autoconf/man/Makefile.in &&
	make && make install
)
failOnError $? "building autoconf"
fi
# build automake 1.11.6
# - autoreconf to avoid conflicts with installed automake
# - automake; configure; make (that will fail) and then automake again
#   to workaround this hell
# - disable doc build
# - disable disable tests build
if [ ! -f tmp/bin/automake ]; then
(
	cd src/automake &&
	echo > doc/Makefile.am &&
	touch NEWS AUTHORS && autoreconf -i && 
	automake &&
	(./configure --prefix=$JEHANNE/hacking/cross/tmp && make; automake) &&
	./configure --prefix=$JEHANNE/hacking/cross/tmp &&
	cp ../../patch/MakeNothing.in doc/Makefile.in &&
	cp ../../patch/MakeNothing.in tests/Makefile.in &&
	make && make install
)
failOnError $? "building automake"
fi
# build libtool 2.4
if [ ! -f tmp/bin/libtool ]; then
(
	cd src/libtool &&
	./configure --prefix=$JEHANNE/hacking/cross/tmp &&
	make && make install
)
failOnError $? "building libtool"
fi

# FINALLY! We have our OUTDATED autotools in tmp/bin
export PATH=$JEHANNE/hacking/cross/tmp/bin:$PATH
export CROSS_DIR=$JEHANNE/hacking/cross
if [ "$BUILD_DIRS_ROOT" = "" ]; then
	export BUILD_DIRS_ROOT=$JEHANNE/hacking/cross/src
fi
if [ ! -d $BUILD_DIRS_ROOT ]; then
	mkdir $BUILD_DIRS_ROOT
fi

function dynpatch {
	# $1 -> path from cross/src
	# $2 -> string to search
	( cd $JEHANNE/hacking/cross/src &&
	  grep -q jehanne $1 ||
	  sed -n -i -e "/$2/r ../patch/$1" -e '1x' -e '2,${x;p}' -e '${x;p}' $1
	)
}

# Patch and build binutils
if [ "$BINUTILS_BUILD_DIR" = "" ]; then
	export BINUTILS_BUILD_DIR=$BUILD_DIRS_ROOT/build-binutils
fi
if [ ! -d $BINUTILS_BUILD_DIR ]; then
	mkdir $BINUTILS_BUILD_DIR
fi
if [ ! -f toolchain/bin/x86_64-jehanne-ar ]; then
(
	sed -i '/jehanne/b; /ELF_TARGET_ID/,/elf_backend_can_gc_sections/s/0x200000/0x1000 \/\/ jehanne hack/g' src/binutils/bfd/elf64-x86-64.c &&
	sed -i '/jehanne/b; s/| -tirtos/| -tirtos* | -jehanne/g' src/binutils/config.sub &&
	dynpatch 'binutils/bfd/config.bfd' '\# END OF targmatch.h' &&
	dynpatch 'binutils/gas/configure.tgt' '  i860-\*-\*)' &&
	( grep -q jehanne src/binutils/ld/configure.tgt || patch -p1 < patch/binutils/ld/configure.tgt ) &&
	cp patch/binutils/ld/emulparams/elf_x86_64_jehanne.sh src/binutils/ld/emulparams/ &&
	cp patch/binutils/ld/emulparams/elf_i386_jehanne.sh src/binutils/ld/emulparams/ &&
	dynpatch 'binutils/ld/Makefile.am' 'eelf_x86_64.c: ' &&
	(grep 'eelf_i386_jehanne.c \\' src/binutils/ld/Makefile.am || sed -i 's/.*ALL_EMULATION_SOURCES = \\.*/&\n\teelf_i386_jehanne.c \\/' src/binutils/ld/Makefile.am) &&
	(grep 'eelf_x86_64_jehanne.c \\' src/binutils/ld/Makefile.am || sed -i 's/.*ALL_64_EMULATION_SOURCES = \\.*/&\n\teelf_x86_64_jehanne.c \\/' src/binutils/ld/Makefile.am) &&
	cd src/binutils/ld && automake && cd ../ &&
	cd $BINUTILS_BUILD_DIR &&
	$CROSS_DIR/src/binutils/configure --prefix=$JEHANNE/hacking/cross/toolchain --with-sysroot=$JEHANNE --target=x86_64-jehanne --enable-interwork --enable-multilib --disable-nls --disable-werror &&
	cp $CROSS_DIR/patch/MakeNothing.in $CROSS_DIR/src/binutils/bfd/doc/Makefile &&
	cp $CROSS_DIR/patch/MakeNothing.in $CROSS_DIR/src/binutils/bfd/po/Makefile &&
	cp $CROSS_DIR/patch/MakeNothing.in $CROSS_DIR/src/binutils/gas/doc/Makefile &&
	cp $CROSS_DIR/patch/MakeNothing.in $CROSS_DIR/src/binutils/binutils/doc/Makefile &&
	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true && 
	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true install
)
failOnError $? "building binutils"
fi

# Patch and build gcc
if [ "$GCC_BUILD_DIR" = "" ]; then
	export GCC_BUILD_DIR=$BUILD_DIRS_ROOT/build-gcc
fi
if [ ! -d $GCC_BUILD_DIR ]; then
	mkdir $GCC_BUILD_DIR
fi
(
	pwd &&
	( grep -q jehanne src/gcc/gcc/config.gcc || patch -p1 < patch/gcc/gcc/config.gcc ) &&
	cd src &&
	cp ../patch/gcc/contrib/download_prerequisites gcc/contrib/download_prerequisites && 
	( cd gcc && ./contrib/download_prerequisites ) &&
	dynpatch 'gcc/config.sub' '-none)' &&
	cp ../patch/gcc/gcc/config/jehanne.h gcc/gcc/config &&
	dynpatch 'gcc/libstdc++-v3/crossconfig.m4' '  \*)' &&
	cd gcc/libstdc++-v3 && autoconf -i && cd ../../ &&
	( pwd && grep -q jehanne gcc/libgcc/config.host ||
	  sed  -i -f ../patch/gcc/libgcc/config.host.sed gcc/libgcc/config.host 
	) &&
	dynpatch 'gcc/fixincludes/mkfixinc.sh' 'i\?86-\*-cygwin\*' &&
	cd $GCC_BUILD_DIR &&
	$CROSS_DIR/src/gcc/configure --target=x86_64-jehanne --prefix=$JEHANNE/hacking/cross/toolchain --with-sysroot=$JEHANNE --enable-languages=c,c++ &&
	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true all-gcc all-target-libgcc && 
	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true install-gcc install-target-libgcc
#	 &&
#	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true all-target-libstdc++-v3 &&
#	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true install-target-libstdc++-v3
)
failOnError $? "building gcc"

# add sh
ln -sf /bin/bash $JEHANNE/hacking/cross/toolchain/bin/x86_64-jehanne-sh
