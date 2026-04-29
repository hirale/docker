#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for container_id in $(docker ps -aq); do
    truncate -s 0 "$(docker inspect --format='{{.LogPath}}' "$container_id")"
done
