#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

set -e

if [ "${COVERITY_SCAN_BRANCH}" != 1 ]; then
	exit 0
fi

cd `dirname $0`
cd ..
export JEHANNE=`pwd`
CROSS_TOOLCHAIN=$JEHANNE/hacking/cross/toolchain
export PATH="$JEHANNE/hacking/bin:$PATH"
export PATH="$JEHANNE/hacking/cross/toolchain/bin:$PATH"
export ARCH=amd64

# since our cross compiler is inside the system root, we need this too
# as it can't find it's own headers
export CPATH=$CROSS_TOOLCHAIN/lib/gcc/x86_64-jehanne/4.9.4/include:$CROSS_TOOLCHAIN/lib/gcc/x86_64-jehanne/4.9.4/include-fixed

git clean -xdf arch/ sys/ qa/ usr/
if [ ! -f "$JEHANNE/hacking/bin/ufs" ]; then
	echo "Cannot find build tools in $JEHANNE/hacking/bin"
	$JEHANNE/hacking/buildtools.sh --no-drawterm
fi
if [ ! -f "$JEHANNE/hacking/cross/toolchain/bin/x86_64-jehanne-gcc" ]; then
	echo "Cannot find cross-compiling toolchain in $JEHANNE/hacking/bin"
	if [ -f "$JEHANNE/tmp/toolchain/bin/x86_64-jehanne-gcc" ]; then
		echo "Found cross-compiling toolchain in $JEHANNE/tmp/toolchain/"
		mv $JEHANNE/tmp/toolchain/* $JEHANNE/hacking/cross/toolchain/
	else
		echo "Creating cross-compiling toolchain..."
		(cd $JEHANNE/hacking/cross/; ./init.sh)
	fi
fi

echo

if [ "$1" != "prepare" ]; then
	export TOOLPREFIX=x86_64-jehanne-
	export CC=x86_64-jehanne-gcc
	build all
fi

if [ "$TRAVIS_BUILD_DIR" != "" ]; then
	echo "Move cross-compiling toolchain to $JEHANNE/tmp/toolchain for Travis caches"
	if [ ! -d "$JEHANNE/tmp/toolchain" ]; then
		mkdir $JEHANNE/tmp/toolchain
	fi
	mv $JEHANNE/hacking/cross/toolchain/* $JEHANNE/tmp/toolchain/
fi
