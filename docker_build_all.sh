#!/bin/bash
set -e
source docker_build_helper.sh

prepare_container

BUILD="$(gcc -dumpmachine)"
for HOST in "$(gcc -dumpmachine)" "x86_64-w64-mingw32"; do
	for TARGET in "x86_64-w64-mingw32" "moxie-elf" "riscv32-unknown-elf" "m68k-elf" "arc-elf" "arm-none-eabi" "$BUILD"; do
		if [ "$TARGET" == "$BUILD" ] && [ "$HOST" != "$TARGET" ]; then
			echo "Skipping $HOST -> $TARGET"
			continue
		fi
		echo "$HOST -> $TARGET"
		docker exec -i gcc_multilib bash /scripts/build.sh "$HOST" "$TARGET"
		docker cp gcc_multilib:/release ./
	done
done

cleanup_container

exit 0
