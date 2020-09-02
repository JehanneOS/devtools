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


#undef STANDARD_STARTFILE_PREFIX
#define STANDARD_STARTFILE_PREFIX "/arch/amd64/lib/"

/* GCC include paths definition START
 */

/* Architecture specific header (u.h) goes here (from config.gcc) */
#define ARCH_INCLUDE_DIR NATIVE_SYSTEM_HEADER_DIR 

/* The default include dir is /sys/include */
#define PORTABLE_INCLUDE_DIR "/sys/include"

#ifdef GPLUSPLUS_INCLUDE_DIR
    /* Pick up GNU C++ generic include files.  */
# define ID_GPLUSPLUS { GPLUSPLUS_INCLUDE_DIR, "G++", 1, 1, GPLUSPLUS_INCLUDE_DIR_ADD_SYSROOT, 0 },
#else
# define ID_GPLUSPLUS 
#endif
#ifdef GPLUSPLUS_TOOL_INCLUDE_DIR
    /* Pick up GNU C++ target-dependent include files.  */
# define ID_GPLUSPLUS_TOOL { GPLUSPLUS_TOOL_INCLUDE_DIR, "G++", 1, 1, GPLUSPLUS_INCLUDE_DIR_ADD_SYSROOT, 1 },
#else
# define ID_GPLUSPLUS_TOOL
#endif
#ifdef GPLUSPLUS_BACKWARD_INCLUDE_DIR
    /* Pick up GNU C++ backward and deprecated include files.  */
# define ID_GPLUSPLUS_BACKWARD { GPLUSPLUS_BACKWARD_INCLUDE_DIR, "G++", 1, 1, GPLUSPLUS_INCLUDE_DIR_ADD_SYSROOT, 0 },
#else
# define ID_GPLUSPLUS_BACKWARD
#endif
#ifdef GCC_INCLUDE_DIR
    /* This is the dir for gcc's private headers.  */
# define ID_GCC { GCC_INCLUDE_DIR, "GCC", 0, 0, 0, 0 },
#else
# define ID_GCC
#endif
#ifdef PREFIX_INCLUDE_DIR
# define ID_PREFIX { PREFIX_INCLUDE_DIR, 0, 0, 1, 0, 0 },
#else
# define ID_PREFIX
#endif
#if defined (CROSS_INCLUDE_DIR) && defined (CROSS_DIRECTORY_STRUCTURE) && !defined (TARGET_SYSTEM_ROOT)
# define JEHANNE_POSIX_INCLUDE_DIR "%:getenv(JEHANNE /posix/include/)"
# define JEHANNE_POSIX_LIB_DIR "%:getenv(JEHANNE /posix/lib/)"
# define ID_CROSS { CROSS_INCLUDE_DIR, "GCC", 0, 0, 0, 0 },
#else
# define ID_CROSS
# define JEHANNE_POSIX_INCLUDE_DIR "/posix/include/"
# define JEHANNE_POSIX_LIB_DIR "/posix/lib/"
#endif
#ifdef TOOL_INCLUDE_DIR
    /* Another place the target system's headers might be.  */
# define ID_TOOL { TOOL_INCLUDE_DIR, "BINUTILS", 0, 1, 0, 0 },
#else
# define ID_TOOL
#endif

#undef INCLUDE_DEFAULTS
#define INCLUDE_DEFAULTS				\
  {							\
    ID_GPLUSPLUS					\
    ID_GPLUSPLUS_TOOL					\
    ID_GPLUSPLUS_BACKWARD				\
    ID_GCC						\
    ID_PREFIX						\
    ID_CROSS						\
    ID_TOOL						\
    { PORTABLE_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { ARCH_INCLUDE_DIR, 0, 0, 0, 1, 0 },		\
    { 0, 0, 0, 0, 0, 0 }				\
  }

/* GCC include paths definition END
 */

/* GCC on Jehanne includes and link libraries from /sys and /arch.
 * To ease the port of POSIX applications, we include a --posixly option
 * to the GCC driver that will be substituted with proper options
 */

#ifdef CROSS_DIRECTORY_STRUCTURE
# define JEHANNE_POSIX_INCLUDE_DIR "%:getenv(JEHANNE /posix/include/)"
# define JEHANNE_POSIX_LIB_DIR "%:getenv(JEHANNE /posix/lib/)"
#else
# define JEHANNE_POSIX_INCLUDE_DIR "/posix/include/"
# define JEHANNE_POSIX_LIB_DIR "/posix/lib/"
#endif

#undef CPP_SPEC
#define CPP_SPEC "%{-posixly:-isystem" JEHANNE_POSIX_INCLUDE_DIR "}"

#undef LINK_SPEC
#define LINK_SPEC "%{-posixly:-L" JEHANNE_POSIX_LIB_DIR "}"

#undef LIB_SPEC
#define LIB_SPEC "%{-posixly:%{!shared:%{g*:-lg} %{!p:%{!pg:-lc}}%{p:-lc_p}%{pg:-lc_p}}} -ljehanne"


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
