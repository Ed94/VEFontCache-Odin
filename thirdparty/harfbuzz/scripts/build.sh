#!/bin/bash

# Source the misc.sh script
misc_script="$(dirname "$0")/helpers/misc.sh"
chmod +x "$misc_script"
source "$misc_script"

path_root=$(git rev-parse --show-toplevel)
path_lib="$path_root/lib"
path_osx="$path_lib/osx"
path_linux64="$path_lib/linux64"

OS=$(uname -s)

# Set the appropriate output directory and file extension
case "$OS" in
    Darwin*)
        path_output="$path_osx"
        shared_lib_extension="dylib"
        ;;
    Linux*)
        path_output="$path_linux64"
        shared_lib_extension="so"
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

url_harfbuzz='https://github.com/harfbuzz/harfbuzz.git'
path_harfbuzz="$path_root/harfbuzz"

build_repo() {
    verify_path "$path_lib"
    verify_path "$path_output"

    # grab the actual repo
    clone_gitrepo "$path_harfbuzz" "$url_harfbuzz"

    pushd "$path_harfbuzz" > /dev/null

    library_type="shared"
    build_type="release"

    # Check if meson is installed
    if ! command -v meson &> /dev/null; then
        echo "Meson is not installed. Please install it and try again."
        exit 1
    fi

    # Meson configure and build
    meson_args=(
        "build"
        "--default-library=$library_type"
        "--buildtype=$build_type"
        "--wrap-mode=forcefallback"
        "-Dglib=disabled"
        "-Dgobject=disabled"
        "-Dcairo=disabled"
        "-Dicu=disabled"
        "-Dgraphite=disabled"
        "-Dfreetype=disabled"
        "-Ddirectwrite=disabled"
        "-Dcoretext=disabled"
    )
    meson "${meson_args[@]}"
    ninja -C build

    popd > /dev/null

    path_build="$path_harfbuzz/build"
    path_src="$path_build/src"
    path_so="$path_src/libharfbuzz.so"
    path_a="$path_src/libharfbuzz.a"

    # Copy files based on build type and library type
    if [ "$build_type" = "debug" ]; then
        # Debug symbols are typically embedded in the .so file on Linux
        # If there's a separate debug file, you would copy it here
        :
    fi

    if [ "$library_type" = "static" ]; then
        cp "$path_a" "$path_linux64/libharfbuzz.a"
    else
        cp "$path_so" "$path_linux64/libharfbuzz.so"
    fi

    echo "Build completed and files copied to $path_linux64"
}

build_repo_without_meson() {
    # Detect the operating system
    OS=$(uname -s)

    echo $url_harfbuzz
    echo $path_harfbuzz
    echo $path_lib
    echo $path_linux64
    verify_path "$path_lib"
    verify_path "$path_linux64"

    path_harfbuzz_build="$path_harfbuzz/build"
    echo $path_harfbuzz_build

    # grab the actual repo
    clone_gitrepo "$path_harfbuzz" "$url_harfbuzz"

    verify_path "$path_harfbuzz_build"
  
    library_type="shared"
    build_type="release"

    pushd "$path_harfbuzz" > /dev/null

    # Determine the latest C++ standard supported by the compiler
    latest_cpp_standard=$(clang++ -dM -E - < /dev/null | grep __cplusplus | awk '{print $3}')
    case $latest_cpp_standard in
        201703L) cpp_flag="-std=c++17" ;;
        202002L) cpp_flag="-std=c++20" ;;
        202302L) cpp_flag="-std=c++23" ;;
        *) cpp_flag="-std=c++14" ;; # Default to C++14 if unable to determine
    esac
    echo "Using C++ standard: $cpp_flag"

    compiler_args=(
        "$cpp_flag"
        "-Wall"
        "-Wextra"
        "-D_REENTRANT"
        "-DHAVE_FALLBACK=1"
        "-DHAVE_OT=1"
        "-DHAVE_SUBSET=1"
        "-DHB_USE_INTERNAL_PARSER"
        "-DHB_NO_COLOR"
        "-DHB_NO_DRAW"
        "-DHB_NO_PARSE"
        "-DHB_NO_MT"
        "-DHB_NO_GRAPHITE2"
        "-DHB_NO_ICU"
        "-DHB_NO_DIRECTWRITE"
        "-I$path_harfbuzz/src"
        "-I$path_harfbuzz"
    )

    if [ "$library_type" = "shared" ]; then
        compiler_args+=("-fPIC")
        compiler_args+=("-DHAVE_DECLSPEC")
        compiler_args+=("-DHARFBUZZ_EXPORTS")
    fi

    if [ "$build_type" = "debug" ]; then
        compiler_args+=("-g" "-O0")
    else
        compiler_args+=("-O2")
    fi

    compiler_args_str="${compiler_args[*]}"

    # Create config.h
    cat > "$path_harfbuzz/config.h" << EOL
#define HB_VERSION_MAJOR 9
#define HB_VERSION_MINOR 0
#define HB_VERSION_MICRO 0
#define HB_VERSION_STRING "9.0.0"
#define HAVE_ROUND 1
#define HB_NO_BITMAP 1
#define HB_NO_CFF 1
#define HB_NO_OT_FONT_CFF 1
#define HB_NO_SUBSET_CFF 1
#define HB_HAVE_SUBSET 0
#define HB_HAVE_OT 0
#define HB_USER_DATA_KEY_DEFINE1(_name) extern HB_EXTERN hb_user_data_key_t _name
EOL

    # Create unity build file
    cat > "$path_harfbuzz_build/harfbuzz_unity.cc" << EOL
#define HB_EXTERN __attribute__((visibility("default")))

// base
#include "config.h"
#include "hb-aat-layout.cc"
#include "hb-aat-map.cc"
#include "hb-blob.cc"
#include "hb-buffer-serialize.cc"
#include "hb-buffer-verify.cc"
#include "hb-buffer.cc"
#include "hb-common.cc"
#include "hb-face.cc"
#include "hb-face-builder.cc"
#include "hb-fallback-shape.cc"
#include "hb-font.cc"
#include "hb-map.cc"
#include "hb-number.cc"
#include "hb-ot-cff1-table.cc"
#include "hb-ot-cff2-table.cc"
#include "hb-ot-color.cc"
#include "hb-ot-face.cc"
#include "hb-ot-font.cc"
#include "hb-outline.cc"
#include "OT/Var/VARC/VARC.cc"
#include "hb-ot-layout.cc"
#include "hb-ot-map.cc"
#include "hb-ot-math.cc"
#include "hb-ot-meta.cc"
#include "hb-ot-metrics.cc"
#include "hb-ot-name.cc"
#include "hb-ot-shaper-arabic.cc"
#include "hb-ot-shaper-default.cc"
#include "hb-ot-shaper-hangul.cc"
#include "hb-ot-shaper-hebrew.cc"
#include "hb-ot-shaper-indic-table.cc"
#include "hb-ot-shaper-indic.cc"
#include "hb-ot-shaper-khmer.cc"
#include "hb-ot-shaper-myanmar.cc"
#include "hb-ot-shaper-syllabic.cc"
#include "hb-ot-shaper-thai.cc"
#include "hb-ot-shaper-use.cc"
#include "hb-ot-shaper-vowel-constraints.cc"
#include "hb-ot-shape-fallback.cc"
#include "hb-ot-shape-normalize.cc"
#include "hb-ot-shape.cc"
#include "hb-ot-tag.cc"
#include "hb-ot-var.cc"
#include "hb-set.cc"
#include "hb-shape-plan.cc"
#include "hb-shape.cc"
#include "hb-shaper.cc"
#include "hb-static.cc"
#include "hb-style.cc"
#include "hb-ucd.cc"
#include "hb-unicode.cc"
EOL

    # Compile unity file
    pushd "$path_harfbuzz_build" > /dev/null
    g++ $compiler_args_str -c harfbuzz_unity.cc -o harfbuzz_unity.o

    if [ $? -ne 0 ]; then
        echo "Compilation failed for unity build"
        popd > /dev/null
        popd > /dev/null
        return 1
    fi

    # Create library
    if [ "$library_type" = "static" ]; then
        ar rcs libharfbuzz.a harfbuzz_unity.o
        if [ $? -ne 0 ]; then
            echo "Static library creation failed"
            popd > /dev/null
            popd > /dev/null
            return 1
        fi
        output_file="libharfbuzz.a"
    else
        g++ -shared -o libharfbuzz.so harfbuzz_unity.o
        if [ $? -ne 0 ]; then
            echo "Shared library creation failed"
            popd > /dev/null
            popd > /dev/null
            return 1
        fi
        output_file="libharfbuzz.so"
    fi

    popd > /dev/null  # path_harfbuzz_build
    popd > /dev/null  # path_harfbuzz

    # Copy files
    cp "$path_harfbuzz_build/$output_file" "$path_linux64/"
    if [ "$library_type" = "shared" ]; then
        if [ -f "$path_harfbuzz_build/libharfbuzz.so" ]; then
            cp "$path_harfbuzz_build/libharfbuzz.so" "$path_linux64/"
        fi
    fi

    echo "Build completed and files copied to $path_linux64"
}

# Uncomment the function you want to use
# build_repo
build_repo_without_meson
