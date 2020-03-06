#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica-drupal
#

# Check if 1st run. Then configure application.
if [ -e /opt/mica/bin/first_run.sh ]; then
  /opt/mica/bin/first_run.sh
  mv /opt/mica/bin/first_run.sh /opt/mica/bin/first_run.sh.done
fi

apache2-foreground
