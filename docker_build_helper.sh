#!/bin/bash
set -e

function prepare_container() {
	docker rm -f gcc_multilib || true
	docker build -t gcc_multilib ./scripts
	docker run -d --name gcc_multilib gcc_multilib sleep 86400 # 24 hours...
	docker cp patches gcc_multilib:/patches
	docker cp scripts gcc_multilib:/scripts
	docker cp test gcc_multilib:/test
}

function cleanup_container() {
	docker cp gcc_multilib:/release ./
	docker rm -f gcc_multilib || true
	docker system prune -f -a
}
