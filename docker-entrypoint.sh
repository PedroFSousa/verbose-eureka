#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-agate

set -e

if [ "$1" = 'app' ]; then
    mkdir -p /etc/ssl/certs/java
    chown -R agate "$AGATE_HOME"
    exec gosu agate /opt/agate/bin/start.sh
fi

exec "$@"
