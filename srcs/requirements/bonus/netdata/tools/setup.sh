#!/bin/bash
set -e

git clone https://github.com/netdata/netdata.git /tmp/netdata

cd /tmp/netdata

./netdata-installer.sh \
    --dont-wait \
    --dont-start-it \
    --stable-channel

rm -rf /tmp/netdata

exec /usr/sbin/netdata -D