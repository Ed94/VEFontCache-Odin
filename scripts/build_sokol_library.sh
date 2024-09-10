#!/bin/bash

path_root="$(git rev-parse --show-toplevel)"
path_backend="$path_root/backend"
path_build="$path_root/build"
path_scripts="$path_root/scripts"
path_thirdparty="$path_root/thirdparty"

path_sokol="$path_thirdparty/sokol"
path_sokol_examples="$path_sokol/examples"

if [ -d "$path_sokol" ] && [ -d "$path_sokol/sokol" ]; then
    mv "$path_sokol/sokol/"* "$path_sokol/"
    rmdir "$path_sokol/sokol"
    rm -rf "$path_sokol_examples"
fi

pushd "$path_sokol" > /dev/null

# Convert build_clibs_linux.sh to Unix line endings
if command -v dos2unix &> /dev/null; then
    dos2unix "./build_clibs_linux.sh"
else
    sed -i 's/\r$//' "./build_clibs_linux.sh"
fi

# Make sure the script is executable
chmod +x "./build_clibs_linux.sh"

check_and_install() {
    if ! dpkg -s $1 &> /dev/null; then
        echo "$1 not found. Attempting to install..."
        sudo apt update && sudo apt install -y $1
        if [ $? -ne 0 ]; then
            echo "Failed to install $1. Please install manually and try again."
            exit 1
        fi
    fi
}

# Check for OpenGL and X11 development libraries
# check_and_install libgl1-mesa-dev
# check_and_install libx11-dev
# check_and_install libxcursor-dev
# check_and_install libxrandr-dev
# check_and_install libxinerama-dev
# check_and_install libxi-dev
# check_and_install libasound2-dev  # ALSA development library

# Run the build script
./build_clibs_linux.sh

popd > /dev/null
