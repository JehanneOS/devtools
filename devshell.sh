#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

export JEHANNE=`git rev-parse --show-toplevel`
REPONAME=`basename $JEHANNE`
JEHANNE_TOOLCHAIN=`dirname $JEHANNE`
JEHANNE_TOOLCHAIN="$JEHANNE_TOOLCHAIN/$REPONAME.TOOLCHAIN"


export PATH="$JEHANNE/hacking/bin:$PATH"
export PATH="$JEHANNE_TOOLCHAIN/cross/posix/bin:$PATH"
export CPATH="$JEHANNE_TOOLCHAIN/cross/posix/lib/gcc/x86_64-jehanne/9.2.0/include:$JEHANNE_TOOLCHAIN/cross/posix/lib/gcc/x86_64-jehanne/9.2.0/include-fixed"
export ARCH=amd64

export TOOLPREFIX=x86_64-jehanne-

# let each developer to customize her environment
if [ "$JEHANNE_DEVELOPER_DIR" = "" ]; then
	JEHANNE_DEVELOPER_DIR=$HOME/.jehanne/
fi
if [ -d "$JEHANNE_DEVELOPER_DIR" ]; then
	export JEHANNE_DEVELOPER_DIR
	if [ -f "$JEHANNE_DEVELOPER_DIR/devshell.sh" ]; then
	if [ "$JEHANNE_DEVELOPER_INIT_RUN" != "1" ]; then
		. "$JEHANNE_DEVELOPER_DIR/devshell.sh"
		export JEHANNE_DEVELOPER_INIT_RUN=1
	fi
	fi
fi

bash --rcfile <(cat ~/.bashrc; echo 'PS1="JehanneDEV $PS1"')
