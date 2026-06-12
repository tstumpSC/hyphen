#ifndef COMPAT_WIN_H
#define COMPAT_WIN_H

/* Standard C headers that MSVC C mode sometimes needs explicitly */
#include <stddef.h>
#include <stdint.h>

#ifdef _WIN32
/* Silence “secure” CRT warnings like fopen/fprintf */
  #ifndef _CRT_SECURE_NO_WARNINGS
  #define _CRT_SECURE_NO_WARNINGS 1
  #endif

  /* ssize_t in MSVC */
  #include <BaseTsd.h>
  typedef SSIZE_T ssize_t;

  /* C99/Posix keywords & funcs that MSVC names differently */
  #ifndef restrict
  #define restrict __restrict
  #endif

  #ifndef inline
  #define inline __inline
  #endif

  #if defined(_MSC_VER) && _MSC_VER < 1900
    #define compat_snprintf _snprintf
  #else
    #define compat_snprintf snprintf
  #endif

  #ifndef strdup
  #define strdup _strdup
  #endif
#endif

/* For bool in strict C mode (older toolchains) */
#if !defined(__cplusplus)
#include <stdbool.h>
#endif

#endif /* COMPAT_WIN_H */