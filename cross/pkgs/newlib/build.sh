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

# To create a Jehanne version of newlib, we need specific OUTDATED versions
# of Autotools that won't compile easily in a modern Linux distro.
export PATH=$JEHANNE/hacking/cross/tmp/bin:$PATH

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

if [ "$NEWLIB_OPTIMIZATION" = "" ]; then
	NEWLIB_OPTIMIZATION=2
fi

export CC=gcc

# NOTE: we use -O0 because apparently vsprintf functions do not
#       work with -O2.
export CFLAGS_FOR_TARGET="-g -gdwarf-2 -ggdb -O$NEWLIB_OPTIMIZATION"

(
	rm -fr $NEWLIB_BUILD &&
	rm -fr $NEWLIB_PREFIX &&
	mkdir $NEWLIB_BUILD &&
	mkdir $NEWLIB_PREFIX &&
	cd $NEWLIB_BUILD &&
	$NEWLIB_SRC/configure --enable-newlib-mb --disable-newlib-fvwrite-in-streamio --prefix=$NEWLIB_PREFIX --target=x86_64-jehanne &&
	make all && make install &&
	rm -fr $JEHANNE/sys/posix/newlib &&
	rm -fr $JEHANNE/arch/amd64/lib/newlib &&
	mv $NEWLIB_PREFIX/x86_64-jehanne/include/ $JEHANNE/sys/posix/newlib &&
	echo "Newlib headers installed at $JEHANNE/sys/posix/newlib/" &&
	mv $NEWLIB_PREFIX/x86_64-jehanne/lib/ $JEHANNE/arch/amd64/lib/newlib/ &&
	echo "Newlib libraries installed at $JEHANNE/arch/amd64/lib/newlib/"
) >> $NEWLIB/newlib.build.log 2>&1
failOnError $? "building newlib"

kill $dotter
wait $dotter 2>/dev/null

echo "done"
exit 0;
