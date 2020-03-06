#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica
#

set -e

if [ "$1" = 'app' ]; then
    mkdir -p /etc/ssl/certs/java
    chown -R mica "$MICA_HOME"
    exec gosu mica /opt/mica/bin/start.sh
fi

exec "$@"
