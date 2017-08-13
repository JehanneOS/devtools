#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

set -e

function finish {
	if [ "$TRAVIS_BUILD_DIR" != "" ]; then
	# ensure that we preserve the toolchain on broken build/test
	if [ -f "$JEHANNE/hacking/cross/toolchain/bin/x86_64-jehanne-gcc" ]; then
		mv $JEHANNE/hacking/cross/toolchain/* $JEHANNE/tmp/toolchain/
	fi
	fi
	(cd $JEHANNE/hacking; git clean -xdf disk-setup/; git checkout disk-setup/syslinux.cfg)
}
trap finish EXIT

if [ "${COVERITY_SCAN_BRANCH}" != 1 ]; then
	cd `dirname $0`
	cd ..
	export JEHANNE=`pwd`
	CROSS_TOOLCHAIN=$JEHANNE/hacking/cross/toolchain
	export PATH="$JEHANNE/hacking/bin:$PATH"
	export PATH="$CROSS_TOOLCHAIN/bin:$PATH"
	export ARCH=amd64

	# since our cross compiler is inside the system root, we need this too
	# as it can't find it's own headers
	export CPATH=$CROSS_TOOLCHAIN/lib/gcc/x86_64-jehanne/4.9.4/include:$CROSS_TOOLCHAIN/lib/gcc/x86_64-jehanne/4.9.4/include-fixed

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
			(cd $JEHANNE/hacking/cross/; ./init.sh; git clean -xdf $JEHANNE/hacking/cross/tmp $JEHANNE/hacking/cross/src/)
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

			echo "Create disk image to run QA checks"
			sed -i -e 's/menu.c32/FromAHCI/g' -e 's/nobootprompt/bootconsole=comconsole nobootprompt/g' $JEHANNE/hacking/disk-setup/syslinux.cfg
			$JEHANNE/hacking/disk-create.sh
			(cd $JEHANNE/hacking/; git checkout disk-setup/syslinux.cfg)

			echo "Run QA checks in sample disk"
			export QA_DISK=$JEHANNE/hacking/sample-disk.img
			echo /qa/check | NCPU=1 runqemu -p 'jehanne#'
		fi

		echo "Move cross-compiling toolchain to $JEHANNE/tmp/toolchain for Travis caches"
		if [ ! -d "$JEHANNE/tmp/toolchain" ]; then
			mkdir $JEHANNE/tmp/toolchain
		fi
	fi
fi
