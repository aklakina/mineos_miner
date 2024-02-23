LOGFILE=./build.log

echo "" > $LOGFILE

echo "Starting build process" | tee -a $LOGFILE

rm -rf ./build
rm -rf ./compiled
mkdir ./build
mkdir ./compiled

echo "Directories cleaned and new ones created" | tee -a $LOGFILE

find . -name "*.lua" -type f ! -path "./compiled/*" ! -path "./.luarocks/*" | while read -r file
do
    # Extract the base name of the file
    base=$(basename "$file")

    # Check if a file with the same name already exists in the build directory
    if [ -e "./build/$base" ]; then
        echo "Error: File $base already exists in the build directory. Exiting." | tee -a $LOGFILE
        exit 1
    else
        # If not, copy the file to the build directory
        cp "$file" ./build
        echo "Copied $file to build directory" | tee -a $LOGFILE
    fi
done

# copy everything from src/resources too
cp -r ./src/resources/* ./build
echo "Copied resources to build directory" | tee -a $LOGFILE

echo "Build process completed" | tee -a $LOGFILE