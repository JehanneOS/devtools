/*
 * This file is part of Jehanne.
 *
 * Copyright (C) 2016-2020 Giacomo Tesio <giacomo@tesio.it>
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
#define LIB_SPEC "-ljehanne"

#undef STANDARD_STARTFILE_PREFIX
#define STANDARD_STARTFILE_PREFIX "/arch/amd64/lib/"

#undef MD_STARTFILE_PREFIX
#define MD_STARTFILE_PREFIX "/arch/amd64/lib/"

/* Architecture specific header (u.h) goes here (from config.gcc) */
#define ARCH_INCLUDE_DIR NATIVE_SYSTEM_HEADER_DIR 

/* The default include dir is /sys/include */
#define PORTABLE_INCLUDE_DIR "/sys/include"

#undef INCLUDE_DEFAULTS
#define INCLUDE_DEFAULTS				\
  {							\
    { PORTABLE_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { ARCH_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { 0, 0, 0, 0, 0, 0 }				\
  }

/* Files that are linked before user code.
   The %s tells gcc to look for these files in the library directory. */
#undef STARTFILE_SPEC
#define STARTFILE_SPEC "crt0.o%s crti.o%s crtbegin.o%s"
 
/* Files that are linked after user code. */
#undef ENDFILE_SPEC
#define ENDFILE_SPEC "crtend.o%s crtn.o%s"
 
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
