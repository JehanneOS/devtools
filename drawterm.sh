#!/bin/bash

# This file is part of Jehanne.
#
# Copyright (C) 2016-2017 Giacomo Tesio <giacomo@tesio.it>

if [ "$JEHANNE" = "" ]; then
	echo ./hacking/drawterm.sh requires the shell started by ./hacking/devshell.sh
	exit 1
fi
drawterm -a 127.0.0.1 -c 127.0.0.1 -u glenda
