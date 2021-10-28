#!/bin/bash

set -eou pipefail


echo "${INPUT_TEST}"
mapfile -t dependencies< <(echo "${INPUT_TEST}")
echo "dependencies: " "${dependencies[*]}"
echo "dependencies1:" "${dependencies[1]}"
