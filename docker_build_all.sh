#!/bin/bash
set -e
if [ ! -e gcc-base ]; then
	git submodule update --init --recursive
fi
source gcc-base/docker_build_helper.sh

prepare_container buster

BUILD="$(gcc -dumpmachine)"
#for TARGET in "riscv32-unknown-elf" "m68k-elf" "x86_64-w64-mingw32" "arc-elf" "arm-none-eabi"; do
for TARGET in "riscv32-unknown-elf" "x86_64-w64-mingw32" "arc-elf" "arm-none-eabi"; do
	for HOST in "$(gcc -dumpmachine)" "x86_64-w64-mingw32" ; do
		if [ "$TARGET" == "$BUILD" ] && [ "$HOST" != "$TARGET" ]; then
			echo "Skipping $HOST -> $TARGET"
			continue
		fi
		echo "$HOST -> $TARGET"
		docker exec -i gcc_multilib bash /scripts/build.sh "$HOST" "$TARGET"
		#WRK_DIR="$(pwd)" ./gcc-base/scripts/build.sh "$HOST" "$TARGET"
	done
done

cleanup_container

exit 0
