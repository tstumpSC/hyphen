#ifdef __cplusplus
extern "C" {
#endif
// Declarations (no 'static')
void* hyphen_load(const char* filename);
void  hyphen_free(void* dict);
int   hyphen_hyphenate2(void* dict, const char* word, int word_size,
                            char* hyphens, char* hyphenated_word,
                            char*** rep, int** pos, int** cut);
int   hyphen_hyphenate3(void* dict, const char* word, int word_size,
                            char* hyphens, char* hyphenated_word,
                            char*** rep, int** pos, int** cut,
                            int lhmin, int rhmin, int clhmin, int crhmin);
#ifdef __cplusplus
}
#endif

// Create real references so the final link *must* pull the objects from libhyphen_ffi.a
__attribute__((used)) static void* _keep1 = (void*)&hyphen_load;
__attribute__((used)) static void* _keep2 = (void*)&hyphen_free;
__attribute__((used)) static void* _keep3 = (void*)&hyphen_hyphenate2;
__attribute__((used)) static void* _keep4 = (void*)&hyphen_hyphenate3;