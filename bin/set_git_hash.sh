#!/bin/bash

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]})

echo "Setting Git Short Hash..."
GIT_HASH=$(git rev-parse --short HEAD | tr -d '\n')
echo "Git Short Hash: ${GIT_HASH}"

echo $GIT_HASH | tr -d '\n' > $SCRIPT_DIR/../site/gitHash.nfo