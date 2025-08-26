# Minimal stub to keep Flutter happy
cmake_minimum_required(VERSION 3.10)
project(hyphen_ffi_dummy)

add_library(hyphen_ffi SHARED dummy.c)
target_sources(hyphen_ffi PRIVATE dummy.c)