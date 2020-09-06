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

/* In Jehanne, GCC has to be able to build two different kind of programs
 * - native, directly repending on Jehanne's development environment
 * - posix, based on the mainstream standards
 *
 * LibPOSIX exists to enable, together with a standard library
 * (newlib, so far) the cooperation of these two worlds.
 *
 * By default, GCC will compile POSIX software looking for standard
 * libraries and includes in /posix subfolders.
 * However, the new option `-9` will enable the compilation of
 * native programs by REMOVING the POSIX stuffs from the various Specs.
 */

/* Architecture specific header (u.h) goes here (from config.gcc) */
#define ARCH_INCLUDE_DIR NATIVE_SYSTEM_HEADER_DIR 

#define PORTABLE_INCLUDE_DIR "/sys/include"

/* C++ : only define values for INCLUDE_DEFAULTS */
#ifdef GPLUSPLUS_INCLUDE_DIR
# define JEHANNE_ID_GPLUSPLUS { GPLUSPLUS_INCLUDE_DIR, "G++", 1, 1, GPLUSPLUS_INCLUDE_DIR_ADD_SYSROOT, 0 },
#else
# define JEHANNE_ID_GPLUSPLUS 
#endif
#ifdef GPLUSPLUS_TOOL_INCLUDE_DIR
# define JEHANNE_ID_GPLUSPLUS_TOOL { GPLUSPLUS_TOOL_INCLUDE_DIR, "G++", 1, 1, GPLUSPLUS_INCLUDE_DIR_ADD_SYSROOT, 1 },
#else
# define JEHANNE_ID_GPLUSPLUS_TOOL
#endif
#ifdef GPLUSPLUS_BACKWARD_INCLUDE_DIR
# define JEHANNE_ID_GPLUSPLUS_BACKWARD { GPLUSPLUS_BACKWARD_INCLUDE_DIR, "G++", 1, 1, GPLUSPLUS_INCLUDE_DIR_ADD_SYSROOT, 0 },
#else
# define JEHANNE_ID_GPLUSPLUS_BACKWARD
#endif

/* GCC's private headers. */
#ifdef GCC_INCLUDE_DIR
# define JEHANNE_IS_GCC " -isystem" GCC_INCLUDE_DIR
# define JEHANNE_ID_GCC { GCC_INCLUDE_DIR, "GCC", 1, 0, 0, 0 },
#else
# define JEHANNE_ID_GCC
# define JEHANNE_IS_GCC
#endif

#ifdef PREFIX_INCLUDE_DIR
# define JEHANNE_IS_PREFIX " -isystem" PREFIX_INCLUDE_DIR
# define JEHANNE_ID_PREFIX { PREFIX_INCLUDE_DIR, 0, 1, 1, 0, 0 },
#else
# define JEHANNE_ID_PREFIX
# define JEHANNE_IS_PREFIX
#endif

#if defined (CROSS_INCLUDE_DIR) && defined (CROSS_DIRECTORY_STRUCTURE) && !defined (TARGET_SYSTEM_ROOT)
# define JEHANNE_IS_CROSS " -isystem" CROSS_INCLUDE_DIR
# define JEHANNE_ID_CROSS { CROSS_INCLUDE_DIR, "GCC", 1, 0, 0, 0 },
#else
# define JEHANNE_ID_CROSS
# define JEHANNE_IS_CROSS
#endif

/* Binutils headers. */
#ifdef TOOL_INCLUDE_DIR
# define JEHANNE_IS_TOOL " -isystem" TOOL_INCLUDE_DIR
# define JEHANNE_ID_TOOL { TOOL_INCLUDE_DIR, "BINUTILS", 1, 1, 0, 0 },
#else
# define JEHANNE_ID_TOOL
# define JEHANNE_IS_TOOL
#endif


#define JEHANNE_POSIX_INCLUDE_DIR "/posix/include"
#define JEHANNE_ID_POSIX { JEHANNE_POSIX_INCLUDE_DIR, 0, 1, 0, 1, 0 },

#ifdef CROSS_DIRECTORY_STRUCTURE
# define JEHANNE_IS_POSIX " -isystem%:getenv(JEHANNE " JEHANNE_POSIX_INCLUDE_DIR ")"
# define JEHANNE_POSIX_LIB_DIR "%:getenv(JEHANNE /posix/lib)"
#else
# define JEHANNE_IS_POSIX " -isystem" JEHANNE_POSIX_INCLUDE_DIR
# define JEHANNE_POSIX_LIB_DIR "/posix/lib"
#endif


/* INCLUDE_DEFAULTS is used by gcc/cppdefault.c
 * The struct is defined in gcc/cppdefault.h
 *
 * struct default_include
 * {
 *   const char *const fname;		// The name of the directory.
 *   const char *const component;	// The component containing the directory
 * 					   (see update_path in prefix.c)
 *   const char cplusplus;		// Only look here if we're compiling C++.
 *   const char cxx_aware;		// Includes in this directory don't need to
 * 					   be wrapped in extern "C" when compiling
 * 					   C++.
 *   const char add_sysroot;		// FNAME should be prefixed by
 * 					   cpp_SYSROOT.
 *   const char multilib;		// FNAME should have appended
 * 					   - the multilib path specified with -imultilib
 * 					     when set to 1,
 * 					   - the multiarch path specified with
 * 					     -imultiarch, when set to 2.
 * };
 *
 * Since C++ assumes a POSIX environment, we include all of the POSIX
 * headers but with `cplusplus = 1`, to not mess native C compilation
 * that have to react to the `-9` option.
 */
#undef INCLUDE_DEFAULTS
#define INCLUDE_DEFAULTS			\
  {						\
    JEHANNE_ID_GPLUSPLUS			\
    JEHANNE_ID_GPLUSPLUS_TOOL			\
    JEHANNE_ID_GPLUSPLUS_BACKWARD		\
    JEHANNE_ID_GCC				\
    JEHANNE_ID_POSIX				\
    JEHANNE_ID_PREFIX				\
    JEHANNE_ID_CROSS				\
    JEHANNE_ID_TOOL				\
    { PORTABLE_INCLUDE_DIR, 0, 0, 0, 1, 0 },	\
    { ARCH_INCLUDE_DIR, 0, 0, 0, 1, 0 },	\
    { 0, 0, 0, 0, 0, 0 }			\
  }

#undef EXTRA_SPECS
#define EXTRA_SPECS \
  { "posixly_isystems",	JEHANNE_IS_GCC		\
			JEHANNE_IS_POSIX	\
			JEHANNE_IS_PREFIX	\
			JEHANNE_IS_CROSS	\
			JEHANNE_IS_TOOL },	\
  { "posixly_lib",	"%{!shared:%{g*:-lg} %{!p:%{!pg:-lc}}%{p:-lc_p}%{pg:-lc_p}} -lposix" },


/* set  CPLUSPLUS_CPP_SPEC to prevent the default fallback to CPP_SPEC */
#define CPLUSPLUS_CPP_SPEC ""

/* These Specs reacts `-9` option by removing POSIX stuff */
#undef CPP_SPEC
#define CPP_SPEC "%{!9:%(posixly_isystems)}"

#undef LINK_SPEC
#define LINK_SPEC "%{!9:-L" JEHANNE_POSIX_LIB_DIR "}"

#undef LIB_SPEC
#define LIB_SPEC "%{!9:%(posixly_lib)} -ljehanne"


/* Files that are linked before user code.
   The %s tells gcc to look for these files in the library directory. */
#undef STARTFILE_SPEC
#define STARTFILE_SPEC "crt0.o%s crti.o%s crtbegin.o%s"
 
/* Files that are linked after user code. */
#undef ENDFILE_SPEC
#define ENDFILE_SPEC "crtend.o%s crtn.o%s"

/* In Jehanne start files will be in /arch/amd64/lib, nearby libjehanne.a
 */
#undef STANDARD_STARTFILE_PREFIX
#define STANDARD_STARTFILE_PREFIX "/arch/amd64/lib/"

 
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
