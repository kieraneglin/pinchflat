#!/bin/bash

if [[ "$@" == *"--dump-json"* ]]; then
  echo '{ "args": "'$@'"}'
else
  echo $@
fi
