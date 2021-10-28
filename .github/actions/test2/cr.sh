#!/bin/bash

set -eou pipefail

# simple changelog: get all commits beetween 2 tags and put them into file
# test=$1
# IFS=" " read -r -a dependencies<<<"${test}"
# echo "dependencies: " "${dependencies[*]}"
# echo "dependencies1:" "${dependencies[1]}"


test2=$1
mapfile -t t2< <(echo "$test2")

echo "t2: " "${t2[*]}"
echo "t2: " "${t2[1]}"

main(){
local t2=("$@")
echo "t2: " "${t2[*]}"
echo "t2: " "${t2[1]}"
}
mapfile -t target< <(echo "$1" )
main "${target[@]}"
export POWER=TEST