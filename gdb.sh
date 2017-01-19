#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

if [ "$JEHANNE" = "" ]; then
        echo $0 requires the shell started by ./hacking/devshell.sh
        exit 1
fi

KERNEL_TO_LOAD=$1

if [ "$KERNEL_TO_LOAD" = "" ]; then
	KERNEL_TO_LOAD=$JEHANNE/arch/amd64/kern/jehanne
fi

echo > $JEHANNE/hacking/_gdb/env
echo "set \$JEHANNE = \"$JEHANNE\"" >> $JEHANNE/hacking/_gdb/env

if [ "$JEHANNE_GDB_LOGS" != "" ]; then
	git rev-parse HEAD > $JEHANNE_GDB_LOGS
	git status --porcelain -b >> $JEHANNE_GDB_LOGS

	echo "set pagination off" >> $JEHANNE/hacking/_gdb/env
	echo "set logging file $JEHANNE_GDB_LOGS" >> $JEHANNE/hacking/_gdb/env
	echo "set logging overwrite off" >> $JEHANNE/hacking/_gdb/env
	echo "set logging on" >> $JEHANNE/hacking/_gdb/env
fi

if [ "$JEHANNE_DEVELOPER_DIR" != "" ]; then
	echo "set \$JEHANNE_DEVELOPER_DIR = \"$JEHANNE_DEVELOPER_DIR\"" >> $JEHANNE/hacking/_gdb/env
	if [ -a $JEHANNE_DEVELOPER_DIR/gdbinit ]; then
		echo source $JEHANNE_DEVELOPER_DIR/gdbinit >> $JEHANNE/hacking/_gdb/env
	fi
else
	echo "set \$JEHANNE_DEVELOPER_DIR = \"$HOME/.jehanne\"" >> $JEHANNE/hacking/_gdb/env
fi

gdb -x $JEHANNE/hacking/_gdb/init $KERNEL_TO_LOAD

rm $JEHANNE/hacking/_gdb/env
