#include <stddef.h>
#include <emscripten/emscripten.h>
#include "../hyphen_lib/hyphen.h"

EMSCRIPTEN_KEEPALIVE
int hyphen_dict_get_utf8(const HyphenDict* p) { return p->utf8; }
