#!/bin/bash

echo "Cross compiling GCC and dependencies"

export WORKING_DIR="$JEHANNE/hacking/cross/pkgs/gcc"

# include x86_64-jehanne-pkg-config in PATH
export PATH="$JEHANNE/hacking/cross/:$PATH"

function failOnError {
	# $1 -> exit status on a previous command
	# $2 -> task description
	if [ $1 -ne 0 ]; then
		echo "ERROR $2"
		echo
		echo BUILD LOG:
		echo
		cat $WORKING_DIR/gcc.build.log
		exit $1
	fi
}

function dynpatch {
	# $1 -> path from $WORKING_DIR/src
	# $2 -> string to search
	( cd $WORKING_DIR/src &&
	  grep -q jehanne $1 ||
	  sed -n -i -e "/$2/r ../patch/$1" -e '1x' -e '2,${x;p}' -e '${x;p}' $1
	)
}

date > $WORKING_DIR/gcc.build.log

# verify libtool is installed
libtool --version >> /dev/null
failOnError $? "libtool installation check"

(cd src && fetch) >> $WORKING_DIR/gcc.build.log
failOnError $? "fetching sources"

echo -n Building libgmp... | tee -a $WORKING_DIR/gcc.build.log
(
	cd src/libgmp &&
	( grep -q jehanne configfsf.sub || patch -p0 < $WORKING_DIR/patch/libgmp.patch ) &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libgmp/6.1.2/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "Building libgmp"
echo done.

#2 Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libgmp/6.1.2/posix/* $JEHANNE/posix

echo -n Building libmpfr... | tee -a $WORKING_DIR/gcc.build.log
(
	cd src/libmpfr &&
	( grep -q jehanne config.sub || patch -p0 < $WORKING_DIR/patch/libmpfr.patch ) &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/pkgs/libgmp/6.1.2/posix/ &&
	cp ../../../../patch/MakeNothing.in doc/Makefile &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpfr/4.0.1/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "Building libmpfr"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libmpfr/4.0.1/posix/* $JEHANNE/posix

echo -n Building libmpc... | tee -a $WORKING_DIR/gcc.build.log
(
	cd src/libmpc &&
	( grep -q jehanne config.sub || ( chmod u+w config.sub &&
	patch -p0 < $WORKING_DIR/patch/libmpc.patch &&
	chmod u-w config.sub ) ) &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/pkgs/libgmp/6.1.2/posix/ --with-mpfr=$JEHANNE/pkgs/libmpfr/4.0.1/posix/ &&
	cp ../../../../patch/MakeNothing.in doc/Makefile &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpc/1.1.0/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "Building libmpc"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libmpc/1.1.0/posix/* $JEHANNE/posix

echo -n Building binutils... | tee -a $WORKING_DIR/gcc.build.log
# Patch and build binutils
if [ "$BINUTILS_BUILD_DIR" = "" ]; then
	export BINUTILS_BUILD_DIR=$WORKING_DIR/build-binutils
fi
( ( grep -q jehanne config.sub || (
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
	cd src/binutils/ld && automake && cd ../ ) ) &&
cd $BINUTILS_BUILD_DIR &&
$WORKING_DIR/src/binutils/configure --prefix=/posix --with-sysroot=$JEHANNE --target=x86_64-jehanne --enable-interwork --enable-multilib --disable-nls --disable-werror &&
cp $WORKING_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/doc/Makefile &&
cp $WORKING_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/po/Makefile &&
cp $WORKING_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/gas/doc/Makefile &&
cp $WORKING_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/binutils/doc/Makefile &&
make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true && 
make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true DESTDIR=$JEHANNE/pkgs/binutils/2.31/ install
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "Building binutils"
fi
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/binutils/2.31/posix/* $JEHANNE/posix
