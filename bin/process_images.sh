#!/bin/bash

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})

# Remove EXIF data from images
echo -e "\n===== Removing EXIF data from images...\n"
$SCRIPT_DIR/Image-ExifTool-12.35/exiftool -overwrite_original -recurse -all= $1

# converting JPEG images
echo -e "\n===== Converting JPEG images...\n"
find $1 -type f -and \( -iname "*.jpg" -o -iname "*.jpeg" \) -exec bash -c '
webp_path=$(sed 's/\.[^.]*$/.webp/' <<< "$0");
if [ ! -f "$webp_path" ]; then
  echo "Converting $0 to $webp_path";
  ./libwebp-1.2.1-linux-x86-64/bin/cwebp -metadata none -quiet -q 75 "$0" -o "$webp_path";
fi;' {} \;

# converting PNG images
echo -e "\n===== Converting PNG images...\n"
find $1 -type f -and -iname "*.png" -exec bash -c '
webp_path=$(sed 's/\.[^.]*$/.webp/' <<< "$0");
if [ ! -f "$webp_path" ]; then
  echo "Converting $0 to $webp_path";
  ./libwebp-1.2.1-linux-x86-64/bin/cwebp -metadata none -quiet -q 75 "$0" -o "$webp_path";
fi;' {} \;
