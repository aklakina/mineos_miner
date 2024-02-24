#!/bin/bash

# Define directories
src_dir="$(pwd)/src"
compiled_dir="$(pwd)/compiled"
lua_minify_dir="$1"

shouldUpload=$2

rm -rf $compiled_dir
mkdir $compiled_dir

# Copy all files from src/resources to compiled
cp -r "$src_dir"/resources/* "$compiled_dir"/

cd "$lua_minify_dir"

find "$src_dir" -name "*.lua" -type f | while read -r file; do
    base=$(basename "$file")
    if [ -e "$compiled_dir/$base" ]; then
        echo "Error: File $base already exists in the build directory. Exiting."
        exit 1
    else
        ./LuaMinify.sh "$file" "$compiled_dir"/"$base" "force"
    fi
done

cd "$compiled_dir"

if [ "$shouldUpload" != "true" ]; then
    exit 0
fi

for file in $(find . -type f); do
    base=$(basename "$file")
    content=$(cat "$compiled_dir"/"$base")
    _ret=$(curl -X POST -d "api_dev_key=${API_KEY}" -d "api_paste_code=$content" -d 'api_option=paste' -d "api_paste_private=0" \
     -d "api_paste_format=lua" -d "api_paste_name=$base" -d "api_paste_expire_date=2W" -d "api_user_key=$USER_KEY" \
     "https://pastebin.com/api/api_post.php")
    _id="${base}=\"${_ret}\",\n${_id}"
done

echo "
ids = {
    $_id
}

for k, v in pairs(ids) do
    rm -f mineos_miner/k
    pastebing get v mineos_miner/k
end
" > updater.lua

curl -X POST -d "api_dev_key=${API_KEY}" -d "api_paste_code=$(cat updater.lua)" -d 'api_option=paste' -d "api_paste_private=1" \
     -d "api_paste_format=lua" -d "api_paste_name=updater.lua" -d "api_paste_expire_date=2W" -d "api_user_key=$USER_KEY" \
    "https://pastebin.com/api/api_post.php"