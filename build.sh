rm -rf ./build
rm -rf ./compiled
mkdir ./build
mkdir ./compiled
find . -name "*.lua" -type f ! -path "./compiled/*" | while read -r file
do
    # Extract the base name of the file
    base=$(basename "$file")

    # Check if a file with the same name already exists in the build directory
    if [ -e "./build/$base" ]; then
        echo "Error: File $base already exists in the build directory. Exiting."
        exit 1
    else
        # If not, copy the file to the build directory
        cp "$file" ./build
    fi
done
# copy everything from src/resources too
cp -r ./src/resources/* ./build