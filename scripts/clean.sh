path_root="$(git rev-parse --show-toplevel)"
path_backend="$path_root/backend"
path_build="$path_root/build"
path_examples="$path_root/examples"
path_scripts="$path_root/scripts"
path_thirdparty="$path_root/thirdparty"

if [ -d "$path_build" ]; then rm -rf "$path_build"; fi
# if [ -d "$path_thirdparty" ]; then rm -rf "$path_thirdparty"; fi