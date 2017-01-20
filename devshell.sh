#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

export JEHANNE=`git rev-parse --show-toplevel`
export PATH="$JEHANNE/hacking/bin:$PATH"
export PATH="$JEHANNE/hacking/cross/toolchain/bin:$PATH"
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
