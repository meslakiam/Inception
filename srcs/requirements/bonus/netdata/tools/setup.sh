#!/bin/bash
set -eu

socket=/var/run/docker.sock
if [ -S "$socket" ]; then
    socket_gid="$(stat -c '%g' "$socket")"
    socket_group="$(getent group "$socket_gid" | cut -d: -f1 || true)"

    if [ -z "$socket_group" ]; then
        socket_group=dockerhost
        groupadd -g "$socket_gid" "$socket_group"
    fi

    usermod -aG "$socket_group" netdata
fi

exec /usr/sbin/netdata -D