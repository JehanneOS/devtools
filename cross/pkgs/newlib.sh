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

# To create a Jehanne version of GCC, we need specific OUTDATED versions
# of Autotools that won't compile easily in a modern Linux distro.

function failOnError {
	# $1 -> exit status on a previous command
	# $2 -> task description
	if [ $1 -ne 0 ]; then
		echo "ERROR $2"
		exit $1
	fi
}

