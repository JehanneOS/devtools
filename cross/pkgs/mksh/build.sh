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
export MKSH=$CROSS_DIR/pkgs/mksh/
export MKSH_SRC=$MKSH/src/
export MKSH_BUILD=$MKSH/out/

export LD_PRELOAD=

echo -n Building mksh.
(
	# Inside parentheses, and therefore a subshell . . .
	while [ 1 ]   # Endless loop.
	do
	  echo -n "."
	  sleep 3
	done
) &
dotter=$!

cd $MKSH

function failOnError {
	# $1 -> exit status on a previous command
	# $2 -> task description
	if [ $1 -ne 0 ]; then
		kill $dotter
		wait $dotter 2>/dev/null

		echo "ERROR $2"
		if [ "$TRAVIS_BUILD_DIR" != "" ]; then
			echo
			cat $MKSH/mksh.build.log
			echo
		fi
		exit $1
	fi
}

export TARGET_OS=Jehanne
export CC=x86_64-jehanne-gcc
export MKSHRC_PATH='~/lib/mkshrc'

(
	git clean -xdf . &&
	mkdir $MKSH_BUILD &&
	cd $MKSH_BUILD &&
	sh ../src/Build.sh &&
	cp mksh $JEHANNE/arch/amd64/cmd/ &&
	sed -e '3,$s/\bbin\b/cmd/g' ../src/dot.mkshrc > mkshrc &&
	mkdir -p $JEHANNE/arch/mksh/lib &&
	cp mkshrc $JEHANNE/arch/mksh/lib &&
	cp mkshrc $JEHANNE/usr/glenda/lib
) > $MKSH/mksh.build.log 2>&1
failOnError $? "building mksh"


kill $dotter
wait $dotter 2>/dev/null

echo "done"
exit 0;
