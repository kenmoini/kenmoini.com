#!/bin/bash

# Remove EXIF data from images
./Image-ExifTool-12.35/exiftool -recurse -all= $0

# converting JPEG images
find $1 -type f -and \( -iname "*.jpg" -o -iname "*.jpeg" \) -exec bash -c '
webp_path=$(sed 's/\.[^.]*$/.webp/' <<< "$0");
if [ ! -f "$webp_path" ]; then
  echo "Converting $0 to $webp_path";
  ./libwebp-1.2.1-linux-x86-64/bin/cwebp -metadata none -quiet -q 75 "$0" -o "$webp_path";
fi;' {} \;

# converting PNG images
find $1 -type f -and -iname "*.png" -exec bash -c '
webp_path=$(sed 's/\.[^.]*$/.webp/' <<< "$0");
if [ ! -f "$webp_path" ]; then
  echo "Converting $0 to $webp_path";
  ./libwebp-1.2.1-linux-x86-64/bin/cwebp -metadata none -quiet -q 75 "$0" -o "$webp_path";
fi;' {} \;
