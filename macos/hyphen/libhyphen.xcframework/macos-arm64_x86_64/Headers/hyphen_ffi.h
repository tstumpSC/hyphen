#include "compat_win.h"
#include "../hyphen_lib/hyphen.h"

#ifdef __EMSCRIPTEN__
#include "web_helper.c"
#endif

#ifndef HYPHEN_FFI_H
#define HYPHEN_FFI_H

#ifdef _WIN32 \
  /* Export symbol for a DLL build. NO QUOTES. */
#ifndef FFI_EXPORT
#define FFI_EXPORT __declspec(dllexport)
#endif
#else
#ifndef FFI_EXPORT
#define FFI_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_EXPORT HyphenDict *hyphen_load(const char *filename);

FFI_EXPORT void hyphen_free(HyphenDict *dict);

FFI_EXPORT int hyphen_hyphenate2(
        HyphenDict *dict,
        const char *word,
        int word_size,
        char *hyphens
);

FFI_EXPORT int hyphen_hyphenate3(
        HyphenDict *dict,
        const char *word,
        int word_size,
        char *hyphens,
        int lhmin,
        int rhmin,
        int clhmin,
        int crhmin
);

#ifdef __cplusplus
}
#endif

#endif // HYPHEN_FFI_H