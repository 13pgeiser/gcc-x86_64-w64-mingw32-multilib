#!/bin/bash
DOCKER_RUN_CMD="docker run --rm  -u $(id -u):$(id -g)"
for helper in *.sh; do
	echo "Processing helper: $helper"
	$DOCKER_RUN_CMD -v "$PWD":/mnt mvdan/shfmt -w /mnt/"$helper"
	$DOCKER_RUN_CMD -e SHELLCHECK_OPTS="" -v "$PWD":/mnt koalaman/shellcheck:stable -x "$helper"
done
