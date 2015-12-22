#!/bin/bash
set -e

if [ "${COVERITY_SCAN_BRANCH}" != 1 ]; then
	export JEHANNE=`git rev-parse --show-toplevel|sed 's/\/hacking//g'`
	export PATH="$JEHANNE/hacking/bin:$PATH"
	export SH=`which rc`
	export ARCH=amd64
	git clean -x -d -f
	(cd $JEHANNE && ./hacking/buildtools.sh)

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
