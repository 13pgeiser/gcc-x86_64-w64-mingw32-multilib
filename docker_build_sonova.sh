#!/bin/bash
set -e
if [ ! -e gcc-base ]; then
	git submodule update --init --recursive
fi
source gcc-base/docker_build_helper.sh

prepare_container jammy

BUILD="$(gcc -dumpmachine)"
for TARGET in "x86_64-w64-mingw32" "arc-elf" "arm-none-eabi" "$BUILD"; do
	for HOST in "$BUILD" "x86_64-w64-mingw32"; do
		if [ "$TARGET" == "$BUILD" ] && [ "$HOST" != "$TARGET" ]; then
			echo "Skipping $HOST -> $TARGET"
			continue
		fi
		echo "$HOST -> $TARGET"
		docker exec -e WRK_DIR=/home/shannon/_tools -e GDB_WITH_PYTHON="--with-python" -i gcc_multilib bash /scripts/build.sh "$HOST" "$TARGET"
	done
done

cleanup_container

exit 0
