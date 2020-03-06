#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica-drupal
#

set -e

if [ "$1" = 'app' ]; then
  exec /opt/mica/bin/start.sh
fi

exec "$@"
