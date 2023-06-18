#!/bin/bash

container_ids=$(docker ps -aq)

for container_id in $container_ids; do
    truncate -s 0 $(docker inspect --format='{{.LogPath}}' $container_id)
done
