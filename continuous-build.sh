#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

set -e

if [ "${COVERITY_SCAN_BRANCH}" != 1 ]; then
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
			mv $JEHANNE/tmp/toolchain/* $JEHANNE/hacking/cross/toolchain/
		else
			echo "Creating cross-compiling toolchain..."
			(cd $JEHANNE/hacking/cross/; ./init.sh)
		fi
	fi

	export TOOLPREFIX=x86_64-jehanne-
	export CC=x86_64-jehanne-gcc

	echo
	echo "Vendorized code verification..."
	echo
	for v in `find $JEHANNE -type f|grep vendor.json`; do
		echo "cd `dirname $v`"
		(cd `dirname $v`; vendor -check)
	done
	echo

	build all

	if [ "$TRAVIS_BUILD_DIR" != "" ]; then
		if [ "$QA_CHECKS" != "" ]; then
			echo "Run QA checks"
			echo /qa/check | NCPU=2 KERNEL=workhorse.32bit KERNDIR=$JEHANNE/hacking/bin/ runqemu
		fi

		echo "Move cross-compiling toolchain to $JEHANNE/tmp/toolchain for Travis caches"
		if [ ! -d "$JEHANNE/tmp/toolchain" ]; then
			mkdir $JEHANNE/tmp/toolchain
		fi
		mv $JEHANNE/hacking/cross/toolchain/* $JEHANNE/tmp/toolchain/
	fi
fi
