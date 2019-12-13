#!/bin/bash

echo "Cross compiling GCC and dependencies"

REPONAME=`basename $JEHANNE`
WORKING_DIR=`dirname $JEHANNE`
WORKING_DIR="$WORKING_DIR/$REPONAME.TOOLCHAIN"
CROSS_DIR="$JEHANNE/hacking/cross"
LOG="$WORKING_DIR/native.build.log"

OPATH=$PATH
export PATH="$CROSS_DIR/wrappers:$PATH"

# include x86_64-jehanne-pkg-config in PATH
#export PATH="$JEHANNE/hacking/cross/:$PATH"
#unset CPATH #set in $JEHANNE/hacking/devshell.sh
#export CPATH="$JEHANNE/posix/include:$JEHANNE/sys/include/apw:$JEHANNE/sys/include:$JEHANNE/arch/amd64/include:$CPATH"

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

(cd $WORKING_DIR/src && fetch) >> $LOG
failOnError $? "fetching sources"



echo -n Building libstdc++-v3... | tee -a $LOG
# libstdc++-v3 is part of GCC but must be built after newlib.
# So we make its build fail and reconfigure it properly after making it fail.
export GCC_BUILD_DIR=$WORKING_DIR/build/gcc
mkdir -p $GCC_BUILD_DIR
(
	rm -fr $WORKING_DIR/src/gcc/isl-0.18.tar.bz2 &&
	rm -fr $WORKING_DIR/src/gcc/isl-0.18 &&
	rm -fr $WORKING_DIR/src/gcc/isl &&
	rm -fr $WORKING_DIR/src/gcc/gmp-6.1.0.tar.bz2 &&
	rm -fr $WORKING_DIR/src/gcc/gmp-6.1.0 &&
	rm -fr $WORKING_DIR/src/gcc/gmp &&
	rm -fr $WORKING_DIR/src/gcc/mpfr-3.1.4.tar.bz2 &&
	rm -fr $WORKING_DIR/src/gcc/mpfr-3.1.4 &&
	rm -fr $WORKING_DIR/src/gcc/mpfr &&
	rm -fr $WORKING_DIR/src/gcc/mpc-1.0.3.tar.gz &&
	rm -fr $WORKING_DIR/src/gcc/mpc-1.0.3 &&
	rm -fr $WORKING_DIR/src/gcc/mpc &&
	cd $GCC_BUILD_DIR &&
	make all-target-libstdc++-v3 ||
	cd x86_64-jehanne/libstdc++-v3 &&
	rm config.cache &&
	$WORKING_DIR/src/gcc/libstdc++-v3/configure --srcdir=$WORKING_DIR/src/gcc/libstdc++-v3 --cache-file=./config.cache --enable-multilib --with-cross-host=x86_64-pc-linux-gnu --prefix=/posix/ --with-sysroot=$JEHANNE --enable-languages=c,c++,lto --program-transform-name='s&^&x86_64-jehanne-&' --disable-option-checking --with-target-subdir=x86_64-jehanne --build=x86_64-pc-linux-gnu --host=x86_64-jehanne --target=x86_64-jehanne
	make && 
	make DESTDIR=$JEHANNE/pkgs/libstdc++-v3/9.2.0/ install
) >> $LOG 2>&1
failOnError $? "building libstdc++-v3"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/libstdc++-v3/9.2.0/posix/* $JEHANNE/posix
find posix/|grep '\.la$'|xargs rm

echo -n Building libgmp... | tee -a $LOG
(
	cd $WORKING_DIR/src/libgmp &&
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
	cd $WORKING_DIR/src/libmpfr &&
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
	cd $WORKING_DIR/src/libmpc &&
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
	export BINUTILS_BUILD_DIR=$WORKING_DIR/build/binutils-native
fi
if [ ! -d $BINUTILS_BUILD_DIR ]; then
	mkdir $BINUTILS_BUILD_DIR
fi
(
	export LIBS="-L$JEHANNE/posix/lib -L$JEHANNE/arch/amd64/lib -lmpc -lmpfr -lgmp -lnewlibc -lposix -lc" &&
	export CC_FOR_BUILD='CPATH="" LIBS="" gcc' &&
	mkdir -p $BINUTILS_BUILD_DIR && cd $BINUTILS_BUILD_DIR &&
	$WORKING_DIR/src/binutils/configure --host=x86_64-jehanne --prefix=/posix --with-sysroot=/ --with-build-sysroot=$JEHANNE  --with-gmp=$JEHANNE/posix/ --with-mpfr=$JEHANNE/posix/ --with-mpc=$JEHANNE/posix/ --enable-interwork --enable-multilib --enable-newlib-long-time_t --disable-nls --disable-werror  &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/doc/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/bfd/po/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/gas/doc/Makefile.in &&
	cp $CROSS_DIR/patch/MakeNothing.in $WORKING_DIR/src/binutils/binutils/doc/Makefile.in &&
	make && 
	make DESTDIR=$JEHANNE/pkgs/binutils/2.33.1/ install
) >> $LOG 2>&1
failOnError $? "Building binutils"

echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -pfr $JEHANNE/pkgs/binutils/2.33.1/posix/* $JEHANNE/posix
rm $JEHANNE/posix/lib/*.la

echo -n Building gcc... | tee -a $LOG
# Patch and build gcc
if [ "$GCC_BUILD_DIR" = "" ]; then
	export GCC_BUILD_DIR=$WORKING_DIR/build/gcc-native
fi
if [ ! -d $GCC_BUILD_DIR ]; then
	mkdir $GCC_BUILD_DIR
fi
(
	cd $GCC_BUILD_DIR &&
	$WORKING_DIR/src/gcc/configure --host=x86_64-jehanne --without-isl --with-newlib --prefix=/posix --with-sysroot=/ --with-build-sysroot=$JEHANNE --enable-languages=c,c++ --with-gmp=$JEHANNE/posix --with-mpfr=$JEHANNE/posix --with-mpc=$JEHANNE/posix --disable-threads --disable-tls --disable-bootstrap --disable-libgomp --disable-werror --disable-nls  &&
	make all-gcc all-target-libgcc && 
	make DESTDIR=$JEHANNE/pkgs/gcc/9.2.0/ install-gcc install-target-libgcc
) >> $LOG 2>&1
failOnError $? "building gcc"

cp -pfr $JEHANNE/pkgs/gcc/9.2.0/posix/* $JEHANNE/posix

#
## add sh
#ln -sf /bin/bash $JEHANNE/hacking/cross/toolchain/bin/x86_64-jehanne-sh

echo "done."
