#!/bin/bash

set -e

path_root="$(git rev-parse --show-toplevel)"
path_backend="$path_root/backend"
path_build="$path_root/build"
path_scripts="$path_root/scripts"
path_thirdparty="$path_root/thirdparty"

path_sokol="."
path_sokol_examples="./examples"

echo "Checking sokol directory structure..."
if [ ! -d "$path_sokol" ]; then
    echo "Error: $path_sokol does not exist."
    exit 1
fi

if [ -d "$path_sokol/sokol" ]; then
    echo "Found nested sokol directory. Restructuring..."
    mv "$path_sokol/sokol/"* "$path_sokol/"
    rmdir "$path_sokol/sokol"
    echo "Nested sokol directory removed."
else
    echo "No nested sokol directory found. Skipping restructure."
fi

if [ -d "$path_sokol_examples" ]; then
    echo "Removing examples directory..."
    rm -rf "$path_sokol_examples"
    echo "Examples directory removed."
else
    echo "No examples directory found. Skipping removal."
fi

pushd "$path_sokol"

# Detect the operating system
OS=$(uname -s)

case "$OS" in
    Linux*)
        echo "Detected Linux operating system"
        # Check for OpenGL and X11 development libraries
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
        # Uncomment these lines if you need to install these dependencies
        # check_and_install libgl1-mesa-dev
        # check_and_install libx11-dev
        # check_and_install libxcursor-dev
        # check_and_install libxrandr-dev
        # check_and_install libxinerama-dev
        # check_and_install libxi-dev
        # check_and_install libasound2-dev  # ALSA development library

        echo "Running Linux build script..."
        ./build_clibs_linux.sh
        ;;
    Darwin*)
        echo "Detected macOS operating system"
        echo "Running macOS build script..."
        ls -al
        ./build_clibs_macos.sh
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

popd

echo "Build process completed."
