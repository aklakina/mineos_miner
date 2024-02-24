#!/bin/bash

# Define directories
src_dir="$(pwd)/src"
compiled_dir="$(pwd)/compiled"
lua_minify_dir="LuaMinify"

rm -rf $compiled_dir
mkdir $compiled_dir

# Copy .lua files from src to compiled, checking for existing files
cd $lua_minify_dir

find "$src_dir" -name "*.lua" -type f | while read -r file; do
    base=$(basename "$file")
    if [ -e "$compiled_dir/$base" ]; then
        echo "Error: File $base already exists in the build directory. Exiting."
        exit 1
    else
        ./LuaMinify.sh "$file" "$compiled_dir"/"$base" "force"
    fi
done

cd "$compiled_dir"/..