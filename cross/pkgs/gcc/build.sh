#!/bin/bash

CROSS_DIR="$JEHANNE/hacking/cross"
LOG="$CROSS_DIR/pkgs/gcc/native-toolchain.build.log"

if [ "$CROSS_PKGS_BUILD" = "1" ]; then
if [ -d $JEHANNE/pkgs/gcc/9.2.0/ ]; then

	echo "Skip cross compilation of GCC to not slowdown whole system build."
	echo "GCC was already detected at $JEHANNE/pkgs/gcc/9.2.0/"
	echo
	echo "If you really want to cross compile GCC, run"
	echo
	echo "   $CROSS_DIR/pkgs/gcc/build.sh"
	echo
	exit

fi
fi

echo "Cross compiling GCC and dependencies"

JEHANNE_TOOLCHAIN=$JEHANNE_TOOLCHAIN

export LD_PRELOAD=

OPATH=$PATH
export PATH="$CROSS_DIR/wrappers:$PATH"

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

date > $LOG

# mock makeinfo (to avoid it as a dependency)
rm -f $JEHANNE/hacking/bin/makeinfo
ln -s `which echo` $JEHANNE/hacking/bin/makeinfo

# verify libtool is installed
libtool --version >> /dev/null
failOnError $? "libtool installation check"

(cd $JEHANNE_TOOLCHAIN/src && fetch) >> $LOG
failOnError $? "fetching sources"



echo -n Building libstdc++-v3... | tee -a $LOG
# libstdc++-v3 is part of GCC but must be built after newlib.
(
	export GCC_BUILD_DIR=$JEHANNE_TOOLCHAIN/build/gcc &&
	mkdir -p $GCC_BUILD_DIR &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/isl-0.18.tar.bz2 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/isl-0.18 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/isl &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/gmp-6.1.0.tar.bz2 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/gmp-6.1.0 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/gmp &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/mpfr-3.1.4.tar.bz2 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/mpfr-3.1.4 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/mpfr &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/mpc-1.0.3.tar.gz &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/mpc-1.0.3 &&
	rm -fr $JEHANNE_TOOLCHAIN/src/gcc/mpc &&
	cd $GCC_BUILD_DIR &&
	mkdir -p $GCC_BUILD_DIR/x86_64-jehanne/libstdc++-v3 &&
	cd $GCC_BUILD_DIR/x86_64-jehanne/libstdc++-v3 &&
	rm -f config.cache &&
	$JEHANNE_TOOLCHAIN/src/gcc/libstdc++-v3/configure --srcdir=$JEHANNE_TOOLCHAIN/src/gcc/libstdc++-v3 --cache-file=./config.cache --enable-multilib --with-cross-host=x86_64-pc-linux-gnu --prefix=/posix --with-sysroot=/ --with-build-sysroot=$JEHANNE --enable-languages=c,c++,lto --program-transform-name='s&^&x86_64-jehanne-&' --disable-option-checking --with-target-subdir=x86_64-jehanne --build=x86_64-pc-linux-gnu --host=x86_64-jehanne --target=x86_64-jehanne &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libstdc++-v3/9.2.0/ install
) >> $LOG 2>&1
failOnError $? "building libstdc++-v3"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libstdc++-v3/9.2.0/posix/* $JEHANNE/posix
find $JEHANNE/posix/|grep '\.la$'|xargs rm

echo -n Building libgmp... | tee -a $LOG
(
	cd $JEHANNE_TOOLCHAIN/src/libgmp &&
	( grep -q jehanne configfsf.sub || patch -p0 < $CROSS_DIR/patch/libgmp.patch ) &&
	./configure --host=x86_64-jehanne --disable-shared --prefix=/posix --with-sysroot=$JEHANNE &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libgmp/6.1.2/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $LOG 2>&1
failOnError $? "Building libgmp"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libgmp/6.1.2/posix/* $JEHANNE/posix
rm $JEHANNE/posix/lib/*.la

echo -n Building libmpfr... | tee -a $LOG
(
	cd $JEHANNE_TOOLCHAIN/src/libmpfr &&
	( grep -q jehanne config.sub || patch -p0 < $CROSS_DIR/patch/libmpfr.patch ) &&
	./configure --host=x86_64-jehanne --disable-shared --prefix=/posix --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/posix/ &&
	cp $CROSS_DIR/patch/MakeNothing.in doc/Makefile.in &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpfr/4.0.1/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $LOG 2>&1
failOnError $? "Building libmpfr"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libmpfr/4.0.1/posix/* $JEHANNE/posix
rm $JEHANNE/posix/lib/*.la

echo -n Building libmpc... | tee -a $LOG
(
	cd $JEHANNE_TOOLCHAIN/src/libmpc &&
	( grep -q jehanne config.sub || ( chmod u+w config.sub &&
	patch -p0 < $CROSS_DIR/patch/libmpc.patch &&
	chmod u-w config.sub ) ) &&
	./configure --host=x86_64-jehanne --disable-shared --prefix=/posix --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/posix/ --with-mpfr=$JEHANNE/posix/ &&
	cp $CROSS_DIR/patch/MakeNothing.in doc/Makefile.in &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpc/1.1.0/ install &&
	libtool --mode=finish $JEHANNE/posix/lib
) >> $LOG 2>&1
failOnError $? "Building libmpc"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libmpc/1.1.0/posix/* $JEHANNE/posix
rm $JEHANNE/posix/lib/*.la

echo -n Building binutils... | tee -a $LOG


# Patch and build binutils
if [ "$BINUTILS_BUILD_DIR" = "" ]; then
	export BINUTILS_BUILD_DIR=$JEHANNE_TOOLCHAIN/build/binutils-native
fi
if [ ! -d $BINUTILS_BUILD_DIR ]; then
	mkdir $BINUTILS_BUILD_DIR
fi
(
	export LIBS="-L$JEHANNE/posix/lib -L$JEHANNE/arch/amd64/lib -lmpc -lmpfr -lgmp" &&
	export CC_FOR_BUILD='CPATH="" LIBS="" gcc' &&
	mkdir -p $BINUTILS_BUILD_DIR && cd $BINUTILS_BUILD_DIR &&
	$JEHANNE_TOOLCHAIN/src/binutils/configure --host=x86_64-jehanne --with-sysroot=/ --with-build-sysroot=$JEHANNE --prefix=/posix --with-gmp=$JEHANNE/posix/ --with-mpfr=$JEHANNE/posix/ --with-mpc=$JEHANNE/posix/ --enable-interwork --enable-multilib --enable-newlib-long-time_t --disable-nls --disable-werror  &&
	cp $CROSS_DIR/patch/MakeNothing.in $JEHANNE_TOOLCHAIN/src/binutils/bfd/doc/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $JEHANNE_TOOLCHAIN/src/binutils/bfd/po/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $JEHANNE_TOOLCHAIN/src/binutils/gas/doc/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $JEHANNE_TOOLCHAIN/src/binutils/binutils/doc/Makefile.in &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/binutils/2.33.1/ install
) >> $LOG 2>&1
failOnError $? "Building binutils"

echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/binutils/2.33.1/posix/* $JEHANNE/posix
rm $JEHANNE/posix/lib/*.la

echo -n "Building gcc (and libgcc)..." | tee -a $LOG
(
	export GCC_BUILD_DIR=$JEHANNE_TOOLCHAIN/build/gcc-native &&
	mkdir -p $GCC_BUILD_DIR &&
	cd $GCC_BUILD_DIR &&
	$JEHANNE_TOOLCHAIN/src/gcc/configure \
		--build=x86_64-pc-linux-gnu --host=x86_64-jehanne --target=x86_64-jehanne \
		--enable-languages=c,c++ \
		--prefix=/posix --with-sysroot=/ --with-build-sysroot=$JEHANNE \
		--without-isl --with-gmp=$JEHANNE/posix --with-mpfr=$JEHANNE/posix --with-mpc=$JEHANNE/posix \
		--disable-multiarch --disable-multilib \
		--disable-shared --disable-threads --disable-tls \
		--disable-libgomp --disable-werror --disable-nls  &&
	make all-gcc &&
	make DESTDIR=$JEHANNE/pkgs/gcc/9.2.0/ install-gcc &&
	make all-target-libgcc &&
	make DESTDIR=$JEHANNE/pkgs/gcc/9.2.0/ install-target-libgcc
) >> $LOG 2>&1
failOnError $? "building gcc"

cp -pfr $JEHANNE/pkgs/gcc/9.2.0/posix/* $JEHANNE/posix

echo "done."
