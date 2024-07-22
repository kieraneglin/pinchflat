#!/bin/bash

# Get the current date in the format YYYY.MM.DD (stripping leading zeros)
DATE=$(date +"%Y.%-m.%-d")

# Get the current version from mix.exs
VERSION=$(grep "version: " mix.exs | cut -d '"' -f2)

echo "Bumping version from $VERSION to $DATE"
# Replace the version in mix.exs with the new version
sed -i "s/version: \"$VERSION\"/version: \"$DATE\"/g" mix.exs

# Run checks to ensure it's a valid mix.exs file
mix check
