#!/bin/bash
set -e

cd `dirname $0`
cd ..
export JEHANNE=`pwd`
export PATH="$JEHANNE/hacking/bin:$PATH"
export PATH="$JEHANNE/hacking/cross/toolchain/bin:$PATH"
export ARCH=amd64
git clean -xdf arch/ sys/ qa/ usr/
if [ ! -f "$JEHANNE/hacking/bin/ufs" ]; then
	echo "Cannot find build tools in $JEHANNE/hacking/bin"
	$JEHANNE/hacking/buildtools.sh
fi
if [ ! -f "$JEHANNE/hacking/cross/toolchain/bin/x86_64-jehanne-gcc" ]; then
	echo "Cannot find cross-compiling toolchain in $JEHANNE/hacking/bin"
	if [ -f "$JEHANNE/tmp/toolchain/bin/x86_64-jehanne-gcc" ]; then
		echo "Found cross-compiling toolchain in $JEHANNE/tmp/toolchain/"
		mv $JEHANNE/tmp/toolchain/ $JEHANNE/hacking/cross/toolchain
	else
		echo "Creating cross-compiling toolchain..."
		(cd $JEHANNE/hacking/cross/; ./init.sh)
	fi
fi

export TOOLPREFIX=x86_64-jehanne-
export CC=gcc

echo

build all

if [ "$TRAVIS_BUILD_DIR" != "" ]; then
	echo "Move cross-compiling toolchain to $JEHANNE/tmp/toolchain for Travis caches"
	mv $JEHANNE/hacking/cross/toolchain $JEHANNE/tmp/toolchain/
fi
