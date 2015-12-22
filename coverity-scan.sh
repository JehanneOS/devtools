#!/bin/bash
set -e

if [ "${COVERITY_SCAN_BRANCH}" != 1 ]; then
	export JEHANNE=`git rev-parse --show-toplevel|sed 's/\/hacking//g'`
	export PATH="$JEHANNE/hacking:$PATH"
	export SH=`which rc`
	export ARCH=amd64
	git clean -x -d -f
	(cd $JEHANNE && ./hacking/buildtools.sh)

	cd $JEHANNE
	build
fi
