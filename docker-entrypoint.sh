#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica-drupal by INESC TEC
#

set -e

if [ "$1" = 'app' ]; then
  exec /opt/mica/bin/start.sh
fi

exec "$@"
