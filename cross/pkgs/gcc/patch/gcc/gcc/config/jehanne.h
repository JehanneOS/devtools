/*
 * This file is part of Jehanne.
 *
 * Copyright (C) 2016 Giacomo Tesio <giacomo@tesio.it>
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

#undef TARGET_JEHANNE
#define TARGET_JEHANNE 1

/* Default arguments you want when running x86_64-jehanne-gcc */
#undef LIB_SPEC
#define LIB_SPEC "-lc"

#undef STANDARD_STARTFILE_PREFIX
#define STANDARD_STARTFILE_PREFIX "/arch/amd64/lib/"

#undef MD_STARTFILE_PREFIX
#define MD_STARTFILE_PREFIX "/arch/amd64/lib/"

#undef GPLUSPLUS_INCLUDE_DIR
#define GPLUSPLUS_INCLUDE_DIR "/posix/g++"

#undef GCC_INCLUDE_DIR
#define GCC_INCLUDE_DIR "/posix/gcc"

/* Architecture specific header (u.h) goes here (from config.gcc) */
#define ARCH_INCLUDE_DIR NATIVE_SYSTEM_HEADER_DIR 

/* The default include dir is /sys/include but... */
#define PORTABLE_INCLUDE_DIR "/sys/include"

#define POSIX_INCLUDE_DIR "/posix/include"

/* ...we have to wrap libc.h and stdio.h with basic POSIX headers */
#define BASIC_POSIX_INCLUDE_DIR "/sys/include/apw"

#undef INCLUDE_DEFAULTS
#define INCLUDE_DEFAULTS				\
  {							\
    { GPLUSPLUS_INCLUDE_DIR, "G++", 1, 1, 1, 0 },	\
    { GCC_INCLUDE_DIR, 0, 0, 0, 1, 0 },			\
    { POSIX_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { BASIC_POSIX_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { ARCH_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { PORTABLE_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { ".", 0, 0, 0, 1, 0 },				\
    { 0, 0, 0, 0, 0, 0 }				\
  }

/* Files that are linked before user code.
   The %s tells gcc to look for these files in the library directory. */
#undef STARTFILE_SPEC
#define STARTFILE_SPEC "crt0.o%s crti.o%s crtbegin.o%s"
 
/* Files that are linked after user code. */
#undef ENDFILE_SPEC
#define ENDFILE_SPEC "crtend.o%s crtn.o%s"
 
/* Don't automatically add extern "C" { } around header files. */
#undef  NO_IMPLICIT_EXTERN_C
#define NO_IMPLICIT_EXTERN_C 1

/* Fix https://gcc.gnu.org/bugzilla/show_bug.cgi?id=67132 */
#undef	WCHAR_TYPE
#define WCHAR_TYPE "unsigned int"
#undef	WCHAR_TYPE_SIZE
#define WCHAR_TYPE_SIZE 32

#undef  LINK_GCC_C_SEQUENCE_SPEC
#define LINK_GCC_C_SEQUENCE_SPEC "%G %L"

/* Additional predefined macros. */
#undef TARGET_OS_CPP_BUILTINS
#define TARGET_OS_CPP_BUILTINS()      \
  do {                                \
    builtin_define ("__jehanne__");      \
    builtin_assert ("system=jehanne");   \
  } while(0);
