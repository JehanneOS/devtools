#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2017 Giacomo Tesio <giacomo@tesio.it>
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

export CROSS_DIR=$JEHANNE/hacking/cross
export NEWLIB=$CROSS_DIR/pkgs/newlib/
export NEWLIB_SRC=$NEWLIB/src/
export NEWLIB_BUILD=$NEWLIB/build/
export NEWLIB_PREFIX=$NEWLIB/output/

export LD_PRELOAD=

echo -n Building newlib.
(
	# Inside parentheses, and therefore a subshell . . .
	while [ 1 ]   # Endless loop.
	do
	  echo -n "."
	  sleep 3
	done
) &
dotter=$!

function failOnError {
	# $1 -> exit status on a previous command
	# $2 -> task description
	if [ $1 -ne 0 ]; then
		kill $dotter
		wait $dotter 2>/dev/null

		echo "ERROR $2"
		if [ "$TRAVIS_BUILD_DIR" != "" ]; then
			echo
			echo "CONFIG.LOG @ $NEWLIB_BUILD/config.log"
			echo
			cat $NEWLIB_BUILD/config.log
			cat $NEWLIB/newlib.build.log
		fi
		exit $1
	fi
}

function mergeLibPOSIX {
	TARGET_LIB=$1
#	echo "Merging $JEHANNE/arch/$ARCH/lib/libposix.a into $TARGET_LIB." &&

#	x86_64-jehanne-ar -M <<EOF
#open $TARGET_LIB
#addlib $JEHANNE/arch/$ARCH/lib/libposix.a
#save
#end
#EOF

}

if [ "$NEWLIB_OPTIMIZATION" = "" ]; then
	NEWLIB_OPTIMIZATION=2
fi

export CC=gcc
export CFLAGS_FOR_TARGET="-g -gdwarf-2 -ggdb -O$NEWLIB_OPTIMIZATION -std=gnu11 -isystem$JEHANNE_TOOLCHAIN/cross/posix/lib/gcc/x86_64-jehanne/9.2.0/include -lposix"

(
	rm -fr $NEWLIB_BUILD &&
	rm -fr $NEWLIB_PREFIX &&
	mkdir $NEWLIB_BUILD &&
	mkdir $NEWLIB_PREFIX &&
	cd $NEWLIB_BUILD &&
	$NEWLIB_SRC/configure --enable-newlib-mb --disable-newlib-fvwrite-in-streamio --disable-newlib-unbuf-stream-opt --prefix=/pkgs/newlib --target=x86_64-jehanne &&
	make all &&
	make DESTDIR=$NEWLIB_PREFIX install &&
	cd $NEWLIB_PREFIX/pkgs/newlib/x86_64-jehanne/lib &&
	mergeLibPOSIX libc.a &&
	( cmp --silent libc.a libg.a || mergeLibPOSIX libg.a ) &&
	cp -fr $NEWLIB_PREFIX/pkgs/newlib/ $JEHANNE/pkgs/ &&
	echo "Newlib headers installed at $JEHANNE/pkgs/newlib/"
) >> $NEWLIB/newlib.build.log 2>&1
failOnError $? "building newlib"



# emultate bind for the cross compiler
mkdir -p $JEHANNE/posix
cp -fr $JEHANNE/pkgs/newlib/x86_64-jehanne/* $JEHANNE/posix

kill $dotter
wait $dotter 2>/dev/null

echo "done"
exit 0;
