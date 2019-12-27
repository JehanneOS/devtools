/*
 * This file is part of Jehanne.
 *
 * Copyright (C) 2020 Giacomo Tesio <giacomo@tesio.it>
 *
 * Jehanne is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 2 of the License.
 *
 * Jehanne is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Jehanne.  If not, see <http://www.gnu.org/licenses/>.
 */
extern "C" {
	
#include <u.h>
#include <libc.h>
#include <posix.h>

void __application_newlib_init(int argc, char *argv[]);

}

__attribute__((__used__)) void
__application_newlib_init(int argc, char *argv[])
{
	sys_rfork(RFFDG | RFREND | RFNOTEG);
	libposix_emulate_SIGCHLD();
}
