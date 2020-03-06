#!/bin/sh
set -e

echo "Configuring Prometheus... "

sed -i "s~CENTRAL_MONITORING_URL~$CENTRAL_MONITORING_URL~" /etc/prometheus/prometheus.yml

echo "Done!"
echo "Prometheus configuration complete."

echo "Starting Prometheus... "
exec "$@"
