#!/bin/bash
set -e
docker rm -f gcc_multilib || true
docker build -t gcc_multilib ./scripts
docker run -d --name gcc_multilib gcc_multilib sleep 43200
docker cp scripts gcc_multilib:/scripts
docker cp test gcc_multilib:/test
docker exec -i gcc_multilib bash /scripts/build.sh
docker cp gcc_multilib:/release ./
docker rm -f gcc_multilib || true
#docker system prune -f -a
exit 0
