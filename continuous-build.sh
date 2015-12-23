#!/bin/bash
set -e

if [ "${COVERITY_SCAN_BRANCH}" != 1 ]; then
	cd `dirname $0`
	cd ..
	export JEHANNE=`pwd`
	export PATH="$JEHANNE/hacking/bin:$PATH"
	export SH=`which rc`
	export ARCH=amd64
	git clean -x -d -f
	if [ ! -f "$JEHANNE/hacking/bin/ufs" ]; then
		echo "Cannot find build tools in $JEHANNE/hacking/bin"
		$JEHANNE/hacking/buildtools.sh
	fi

	echo
	echo "Vendorized code verification..."
	echo
	for v in `find $JEHANNE -type f|grep vendor.json`; do
		echo "cd `dirname $v`"
		(cd `dirname $v`; vendor -check)
	done
	echo

	build all
fi
