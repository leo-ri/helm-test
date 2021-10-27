#!/bin/bash

set -eou pipefail

# simple changelog: get all commits beetween 2 tags and put them into file
test=$1
test2=$2
IFS=" " read -r -a dependencies<<<"${test}"
mapfile -t t2< <(echo "$test2")
echo "dependencies: " "${dependencies[*]}"
echo "dependencies1:" "${dependencies[1]}"
echo "t2: " "${t2[*]}"
echo "t2: " "${t2[1]}"
