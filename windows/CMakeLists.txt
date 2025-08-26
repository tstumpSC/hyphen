cmake_minimum_required(VERSION 3.14)
project(hyphen_ffi LANGUAGES C)

set(BUILD_SHARED_LIBS ON)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(NATIVE_SRC "${CMAKE_CURRENT_LIST_DIR}/../src/wrapper")

# Collect libhyphen sources (list them explicitly or glob if you prefer)
set(LIBHYPHEN_SRC
        "${CMAKE_CURRENT_LIST_DIR}/../src/hyphen_lib/hyphen.c"
        "${CMAKE_CURRENT_LIST_DIR}/../src/hyphen_lib/hnjalloc.c"
)

add_library(hyphen_ffi SHARED
        "${NATIVE_SRC}/hyphen_ffi.c"
        ${LIBHYPHEN_SRC}
)

if (MSVC)
    target_compile_options(hyphen_ffi PRIVATE
            /wd4267  # size_t -> int
            /wd4244  # 64-bit -> 32-bit
            /wd4477  # printf format mismatch
    )
endif()

target_include_directories(hyphen_ffi PRIVATE
        "${NATIVE_SRC}"
)

# Static CRT (avoids VC++ redistributable dependency)
if(MSVC)
    foreach(flag_var CMAKE_C_FLAGS CMAKE_C_FLAGS_DEBUG CMAKE_C_FLAGS_RELEASE)
        string(REPLACE "/MD" "/MT" ${flag_var} "${${flag_var}}")
        string(REPLACE "/MDd" "/MTd" ${flag_var} "${${flag_var}}")
    endforeach()
endif()

# Define for Windows quirks if needed
target_compile_definitions(hyphen_ffi PRIVATE _CRT_SECURE_NO_WARNINGS)

set_target_properties(hyphen_ffi PROPERTIES OUTPUT_NAME "hyphen_ffi")

set(RUNNER_OUT_DIR "${CMAKE_BINARY_DIR}/runner/$<CONFIG>")

add_custom_command(TARGET hyphen_ffi POST_BUILD
        # 1) ensure the directory exists (first build fix)
        COMMAND ${CMAKE_COMMAND} -E make_directory "${RUNNER_OUT_DIR}"
        # 2) copy the freshly built DLL there
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:hyphen_ffi>
        "${RUNNER_OUT_DIR}"
        VERBATIM
)