#!/bin/bash
set -e
source docker_build_helper.sh

prepare_container

docker exec -i gcc_multilib bash /scripts/build.sh "$(gcc -dumpmachine)" "x86_64-w64-mingw32"
docker exec -i gcc_multilib bash /scripts/build.sh "x86_64-w64-mingw32" "x86_64-w64-mingw32"
docker cp gcc_multilib:/release ./

cleanup_container

exit 0
