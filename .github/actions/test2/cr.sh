#!/bin/bash

set -eou pipefail

# simple changelog: get all commits beetween 2 tags and put them into file
echo "${INPUT_TEST}"
IFS=" " read -r -a dependencies<<<"${INPUT_TEST}"
echo "dependencies: " "${dependencies[*]}"
echo "dependencies1:" "${dependencies[1]}"
