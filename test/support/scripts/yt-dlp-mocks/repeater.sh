#!/bin/bash

# Args come in the format of "<unknown number of args> --print-to-file <output template> <file location> <unknown number of args>".
# I need to extract <file location> and write all args to it.

# Extract the file location (in an unknown position BUT it's 2 args after --print-to-file).
for ((i = 1; i <= $#; i++)); do
  if [ "${!i}" == "--print-to-file" ]; then
    # Extract the file location.
    file_location="${@:i+2:1}"
    break
  fi
done

if [ "${!i}" == "--print-to-file" ]; then
  # Write all args to the file
  echo "$@" >"$file_location"
else
  echo "$@"
fi
