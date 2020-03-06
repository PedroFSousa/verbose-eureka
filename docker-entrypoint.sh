#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-opal
set -e

if [ "$1" = 'app' ]; then
    mkdir -p /etc/ssl/certs/java
    chown -R opal "$OPAL_HOME"
    exec gosu opal /opt/opal/bin/start.sh
fi

exec "$@"
