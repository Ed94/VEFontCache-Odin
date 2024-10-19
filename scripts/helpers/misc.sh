#!/bin/bash

clone_gitrepo() {
    local path="$1"
    local url="$2"

    if [ -d "$path" ]; then
        # git -C "$path" pull
        :
    else
        echo "Cloning $url ..."
        git clone "$url" "$path"
    fi
}

get_ini_content() {
    local path_file="$1"
    declare -A ini

    local current_section=""
    while IFS= read -r line; do
        if [[ $line =~ ^\[(.+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            ini["$current_section"]=""
        elif [[ $line =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            if [ -n "$current_section" ]; then
                ini["$current_section,$key"]="$value"
            fi
        fi
    done < "$path_file"

    # To use this function, you would need to pass the result by reference
    # and then access it in the calling function
}

invoke_with_color_coded_output() {
    local command="$1"
    eval "$command" 2>&1 | while IFS= read -r line; do
        if [[ "$line" =~ [Ee]rror ]]; then
            echo -e "\033[0;31m\t$line\033[0m"  # Red for errors
        elif [[ "$line" =~ [Ww]arning ]]; then
            echo -e "\033[0;33m\t$line\033[0m"  # Yellow for warnings
        else
            echo -e "\033[0;37m\t$line\033[0m"  # White for other output
        fi
    done
}

update_git_repo() {
    local path="$1"
    local url="$2"
    local build_command="$3"

    if [ -z "$build_command" ]; then
        echo "Attempted to call update_git_repo without build_command specified"
        return
    fi

    local repo_name=$(basename "$url" .git)

    local last_built_commit="$path_build/last_built_commit_$repo_name.txt"
    if [ ! -d "$path" ]; then
        echo "Cloning repo from $url to $path"
        git clone "$url" "$path"

        chmod +x "$build_command"

        echo "Building $url"
        pushd "$path" > /dev/null
        eval "$build_command"
        popd > /dev/null

        git -C "$path" rev-parse HEAD > "$last_built_commit"
        binaries_dirty=true
        echo
        return
    fi

    git -C "$path" fetch
    local latest_commit_hash=$(git -C "$path" rev-parse '@{u}')
    local last_built_hash=""
    [ -f "$last_built_commit" ] && last_built_hash=$(cat "$last_built_commit")

    if [ "$latest_commit_hash" = "$last_built_hash" ]; then
        echo
        return
    fi

    echo "Build out of date for: $path, updating"
    echo 'Pulling...'
    git -C "$path" pull

    chmod +x "$build_command"

    echo "Building $url"
    pushd "$path" > /dev/null
    eval "$build_command"
    popd > /dev/null

    echo "$latest_commit_hash" > "$last_built_commit"
    binaries_dirty=true
    echo
}

verify_path() {
    local path="$1"
    if [ ! -d "$path" ]; then
        mkdir -p "$path"
        echo "Created directory: $path"
    fi
}
