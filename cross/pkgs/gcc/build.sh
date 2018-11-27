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

date > $WORKING_DIR/gcc.build.log

(cd src && fetch) >> $WORKING_DIR/gcc.build.log
failOnError $? "fetching sources"

echo -n Building libgmp...
(
	cd src/libgmp &&
	patch -p0 < $WORKING_DIR/patch/libgmp.patch &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libgmp/6.1.2/ install
) >> $WORKING_DIR/gcc.build.log
failOnError $? "Building libgmp"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -fr $JEHANNE/pkgs/libgmp/6.1.2/posix/* $JEHANNE/posix

echo -n Building libmpfr...
(
	cd src/libmpfr &&
	patch -p0 < $WORKING_DIR/patch/libmpfr.patch &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/pkgs/libgmp/6.1.2/posix/ &&
	cp ../../../../patch/MakeNothing.in doc/Makefile &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpfr/4.0.1/ install
) >> $WORKING_DIR/gcc.build.log
failOnError $? "Building libmpfr"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -fr $JEHANNE/pkgs/libmpfr/4.0.1/posix/* $JEHANNE/posix

echo -n Building libmpc...
(
	cd src/libmpc &&
	chmod u+w config.sub &&
	patch -p0 < $WORKING_DIR/patch/libmpc.patch &&
	chmod u-w config.sub &&
	./configure --host=x86_64-jehanne --prefix=/posix/ --with-sysroot=$JEHANNE --with-gmp=$JEHANNE/pkgs/libgmp/6.1.2/posix/ --with-mpfr=$JEHANNE/pkgs/libmpfr/4.0.1/posix/ &&
	cp ../../../../patch/MakeNothing.in doc/Makefile &&
	make &&
	make DESTDIR=$JEHANNE/pkgs/libmpc/1.1.0/ install
) >> $WORKING_DIR/gcc.build.log
failOnError $? "Building libmpc"
echo done.

# Copy to /posix (to emulate bind during cross compilation)
cp -fr $JEHANNE/pkgs/libmpc/4.0.1/posix/* $JEHANNE/posix
