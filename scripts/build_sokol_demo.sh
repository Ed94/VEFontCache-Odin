#!/bin/bash

set -e

source "$(dirname "$0")/helpers/misc.sh"

path_root=$(git rev-parse --show-toplevel)
path_backend="$path_root/backend"
path_build="$path_root/build"
path_examples="$path_root/examples"
path_scripts="$path_root/scripts"
path_thirdparty="$path_root/thirdparty"

verify_path "$path_build"
verify_path "$path_thirdparty"

path_system_details="$path_build/system_details.ini"
if [ -f "$path_system_details" ]; then
    CoreCount_Physical=$(grep "PhysicalCores" "$path_system_details" | cut -d'=' -f2)
    CoreCount_Logical=$(grep "LogicalCores" "$path_system_details" | cut -d'=' -f2)
else
    OS=$(uname -s)
    case "$OS" in
        Darwin*)
            CoreCount_Physical=$(sysctl -n hw.physicalcpu)
            CoreCount_Logical=$(sysctl -n hw.logicalcpu)
            ;;
        Linux*)
            CoreCount_Physical=$(nproc --all)
            CoreCount_Logical=$(nproc)
            ;;
        *)
            echo "Unsupported operating system: $OS"
            CoreCount_Physical=1
            CoreCount_Logical=1
            ;;
    esac

    echo "[CPU]" > "$path_system_details"
    echo "PhysicalCores=$CoreCount_Physical" >> "$path_system_details"
    echo "LogicalCores=$CoreCount_Logical" >> "$path_system_details"
fi
echo "Core Count - Physical: $CoreCount_Physical Logical: $CoreCount_Logical"

url_freetype='https://github.com/Ed94/odin-freetype.git'
url_harfbuzz='https://github.com/Ed94/harfbuzz-odin.git'
url_sokol='https://github.com/floooh/sokol-odin.git'
url_sokol_tools='https://github.com/floooh/sokol-tools-bin.git'

path_freetype="$path_thirdparty/freetype"
path_harfbuzz="$path_thirdparty/harfbuzz"
path_sokol="$path_thirdparty/sokol"
path_sokol_tools="$path_thirdparty/sokol-tools"

sokol_build_clibs_command="$path_scripts/build_sokol_library.sh"

clone_gitrepo "$path_freetype" "$url_freetype"
clone_gitrepo "$path_sokol_tools" "$url_sokol_tools"

update_git_repo "$path_sokol" "$url_sokol" "$sokol_build_clibs_command"
update_git_repo "$path_harfbuzz" "$url_harfbuzz" "./scripts/build.sh"

pushd "$path_thirdparty" > /dev/null
    case "$OS" in
        Darwin*)
            path_harfbuzz_dlls="$path_harfbuzz/lib/osx"
            ;;
        Linux*)
            path_harfbuzz_dlls="$path_harfbuzz/lib/linux64"
            ;;
        *)
            echo "Unsupported operating system: $OS"
            CoreCount_Physical=1
            CoreCount_Logical=1
            ;;
    esac
    if ls "$path_harfbuzz_dlls"/*.so 1> /dev/null 2>&1; then
        cp "$path_harfbuzz_dlls"/*.so "$path_build/"
    else
        echo "Warning: No .so files found in $path_harfbuzz_dlls"
    fi
popd > /dev/null

path_stb_truetype="$path_thirdparty/stb/src"

pushd "$path_stb_truetype" > /dev/null
    make
popd > /dev/null

source "$(dirname "$0")/helpers/odin_compiler_defs.sh"

pkg_collection_backend="backend=$path_backend"
pkg_collection_thirdparty="thirdparty=$path_thirdparty"

pushd "$path_build" > /dev/null

function build_SokolBackendDemo {
    echo 'Building VEFontCache: Sokol Backend Demo'

    compile_shaders="$path_scripts/compile_sokol_shaders.sh"
    if [ -f "$compile_shaders" ]; then
        bash "$compile_shaders"
    else
        echo "Warning: $compile_shaders not found. Skipping shader compilation."
    fi

    executable="$path_build/sokol_demo"

    build_args=(
        "$command_build"
        "../examples/sokol_demo"
        "$flag_output_path$executable"
        "${flag_collection}${pkg_collection_backend}"
        "${flag_collection}${pkg_collection_thirdparty}"
        # "$flag_micro_architecture_native"
        "$flag_use_separate_modules"
        "${flag_thread_count}${CoreCount_Physical}"
        # "$flag_optimize_none"
        # "$flag_optimize_minimal"
        "$flag_optimize_speed"
        # "$flag_optimize_aggressive"
        # "$flag_debug"
        "$flag_show_timings"
        # "$flag_show_system_call"
        # "$flag_no_bounds_check"
        # "$flag_no_thread_checker"
        # "$flag_default_allocator_nil"
        "${flag_max_error_count}10"
        # "$flag_sanitize_address"
        # "$flag_sanitize_memory"
    )

    invoke_with_color_coded_output "$odin_compiler ${build_args[*]}"
}

build_SokolBackendDemo

popd > /dev/null
