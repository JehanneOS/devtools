#!/bin/bash

echo "Cross compiling GCC and dependencies"

export WORKING_DIR="$JEHANNE/hacking/cross/pkgs/gcc"

# include x86_64-jehanne-pkg-config in PATH
export PATH="$JEHANNE/hacking/cross/:$PATH"
unset CPATH #set in $JEHANNE/hacking/devshell.sh

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

# mock makeinfo (to avoid it as a dependency)
rm -f $JEHANNE/hacking/bin/makeinfo
ln -s `which echo` $JEHANNE/hacking/bin/makeinfo

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

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libgmp/6.1.2/posix/* $JEHANNE/posix

echo -n Building libmpfr... | tee -a $WORKING_DIR/gcc.build.log
(
	cd src/libmpfr &&
	( grep -q jehanne config.sub || patch -p0 < $WORKING_DIR/patch/libmpfr.patch ) &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/pkgs/libgmp/6.1.2/posix/ &&
	cp ../../../../patch/MakeNothing.in doc/Makefile.in &&
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
	cp ../../../../patch/MakeNothing.in doc/Makefile.in &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpc/1.1.0/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "Building libmpc"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libmpc/1.1.0/posix/* $JEHANNE/posix

echo -n Building binutils... | tee -a $WORKING_DIR/gcc.build.log

export CPATH="$JEHANNE/posix/include:$JEHANNE/sys/include:$JEHANNE/arch/amd64/include:$JEHANNE/hacking/cross/toolchain/lib/gcc/x86_64-jehanne/4.9.4/include:$JEHANNE/hacking/cross/toolchain/lib/gcc/x86_64-jehanne/4.9.4/include-fixed"
export LIBS="-L$JEHANNE/posix/lib -lnewlibc -lposix -lc"
export CC_FOR_BUILD='CPATH="" LIBS="" gcc'

# Patch and build binutils
if [ "$BINUTILS_BUILD_DIR" = "" ]; then
	export BINUTILS_BUILD_DIR=$WORKING_DIR/build-binutils
fi
if [ ! -d $BINUTILS_BUILD_DIR ]; then
	mkdir $BINUTILS_BUILD_DIR
fi
( ( grep -q jehanne src/binutils/config.sub || (
echo done
	sed -i '/jehanne/b; /ELF_TARGET_ID/,/elf_backend_can_gc_sections/s/0x200000/0x1000 \/\/ jehanne hack/g' src/binutils/bfd/elf64-x86-64.c &&
	sed -i '/jehanne/b; s/| midnightbsd\*/| midnightbsd* | jehanne*/g' src/binutils/config.sub &&
	dynpatch 'binutils/bfd/config.bfd' '\# END OF targmatch.h' &&
	dynpatch 'binutils/gas/configure.tgt' '  i386-\*-darwin\*)' &&
	( grep -q jehanne src/binutils/ld/configure.tgt || patch -p1 < patch/binutils/ld/configure.tgt ) &&
	cp patch/binutils/ld/emulparams/elf_x86_64_jehanne.sh src/binutils/ld/emulparams/ &&
	cp patch/binutils/ld/emulparams/elf_i386_jehanne.sh src/binutils/ld/emulparams/ &&
	dynpatch 'binutils/ld/Makefile.am' 'eelf_x86_64.c: ' &&
	(grep 'eelf_i386_jehanne.c \\' src/binutils/ld/Makefile.am || sed -i 's/.*ALL_EMULATION_SOURCES = \\.*/&\n\teelf_i386_jehanne.c \\/' src/binutils/ld/Makefile.am) &&
	(grep 'eelf_x86_64_jehanne.c \\' src/binutils/ld/Makefile.am || sed -i 's/.*ALL_64_EMULATION_SOURCES = \\.*/&\n\teelf_x86_64_jehanne.c \\/' src/binutils/ld/Makefile.am) &&
	cd src/binutils/ld && automake-1.15 && cd ../ 
	) ) &&
	mkdir -p $BINUTILS_BUILD_DIR && cd $BINUTILS_BUILD_DIR &&
	$WORKING_DIR/src/binutils/configure --host=x86_64-jehanne --prefix=/posix --with-sysroot=$JEHANNE --target=x86_64-jehanne --enable-interwork --enable-multilib --enable-newlib-long-time_t --disable-nls --disable-werror &&
	cp $WORKING_DIR/../../patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/doc/Makefile.in &&
	cp $WORKING_DIR/../../patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/po/Makefile.in &&
	cp $WORKING_DIR/../../patch/MakeNothing.in $WORKING_DIR/src/binutils/gas/doc/Makefile.in &&
	cp $WORKING_DIR/../../patch/MakeNothing.in $WORKING_DIR/src/binutils/binutils/doc/Makefile.in &&
	make && 
	make DESTDIR=$JEHANNE/pkgs/binutils/2.33.1/ install
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "Building binutils"

echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/binutils/2.33.1/posix/* $JEHANNE/posix


echo -n Building gcc... | tee -a $WORKING_DIR/gcc.build.log
# Patch and build gcc
if [ "$GCC_BUILD_DIR" = "" ]; then
	export GCC_BUILD_DIR=$WORKING_DIR/build-gcc
fi
if [ ! -d $GCC_BUILD_DIR ]; then
	mkdir $GCC_BUILD_DIR
fi
(
	pwd &&
	( grep -q jehanne src/gcc/gcc/config.gcc || patch -p1 < patch/gcc.patch ) &&
	cp patch/gcc/gcc/config/jehanne.h src/gcc/gcc/config &&
	sed -i 's/ftp/https/g' src/gcc/contrib/download_prerequisites &&
	cd src &&
	( cd gcc && ./contrib/download_prerequisites ) &&
	( cd gcc/libstdc++-v3 && autoconf -i ) &&
	cd $GCC_BUILD_DIR &&
	$WORKING_DIR/src/gcc/configure --host=x86_64-jehanne --target=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --enable-languages=c,c++ &&
	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true all-gcc all-target-libgcc && 
	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true DESTDIR=$JEHANNE/pkgs/gcc/9.2.0/ install-gcc install-target-libgcc
#	 &&
#	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true all-target-libstdc++-v3 &&
#	make MAKEINFO=true MAKEINFOHTML=true TEXI2DVI=true TEXI2PDF=true DVIPS=true install-target-libstdc++-v3
) >> $WORKING_DIR/gcc.build.log 2>&1
failOnError $? "building gcc"

cp -pfr $JEHANNE/pkgs/gcc/9.2.0/posix/* $JEHANNE/posix

#
## add sh
#ln -sf /bin/bash $JEHANNE/hacking/cross/toolchain/bin/x86_64-jehanne-sh


#cp src/gcc.bkp/gcc/config.gcc src/gcc/gcc/config.gcc
#cp src/gcc.bkp/config.sub src/gcc/config.sub
#cp src/gcc.bkp/fixincludes/mkfixinc.sh src/gcc/fixincludes/mkfixinc.sh
#cp src/gcc.bkp/libgcc/config.host src/gcc/libgcc/config.host



echo "done."
