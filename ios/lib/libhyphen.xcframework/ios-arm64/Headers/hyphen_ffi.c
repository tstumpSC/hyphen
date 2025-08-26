#include "compat_win.h"
#include "hyphen_ffi.h"
#include <stdlib.h>

#ifdef _EMSCRIPTEN_
#include <emscripten/emscripten.h>
#endif

FFI_EXPORT HyphenDict *hyphen_load(const char *filename) {
    return hnj_hyphen_load(filename);
}

FFI_EXPORT void hyphen_free(HyphenDict *dict) {
    hnj_hyphen_free(dict);
}

FFI_EXPORT int hyphen_hyphenate2(
        HyphenDict *dict,
        const char *word,
        int word_size,
        char *hyphens
) {
    char **rep = NULL;
    int *pos = NULL;
    int *cut = NULL;

    int result = hnj_hyphen_hyphenate2(dict, word, word_size,
                                       hyphens, NULL, &rep, &pos, &cut);

    free(rep);
    free(pos);
    free(cut);
    return result;
}

FFI_EXPORT int hyphen_hyphenate3(
        HyphenDict *dict,
        const char *word,
        int word_size,
        char *hyphens,
        int lhmin,
        int rhmin,
        int clhmin,
        int crhmin
) {
    char **rep = NULL;
    int *pos = NULL;
    int *cut = NULL;

    int result = hnj_hyphen_hyphenate3(dict, word, word_size, hyphens, NULL, &rep, &pos, &cut,
                                       lhmin, rhmin, clhmin, crhmin);

    free(rep);
    free(pos);
    free(cut);
    return result;
}