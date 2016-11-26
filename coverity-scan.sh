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
