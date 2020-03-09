#!/bin/sh -e

NODE_NAME=$(echo $DOMAIN)

echo "node_meta{node_id=\"$NODE_ID\", container_label_com_docker_swarm_node_id=\"$NODE_ID\", node_name=\"$NODE_NAME\"} 1" > /etc/node-exporter/node-meta.prom

echo "node_env_var{node_domain=\"$DOMAIN\", allow_anonymous_stats=\"$ALLOW_ANONYMOUS_STATS\", https_proxy=\"$HTTPS_PROXY\", http_proxy=\"$HTTP_PROXY\", server_system_version=\"$SERVER_SYSTEM_VERSION\", server_system_name=\"$SERVER_SYSTEM_NAME\", cert_type=\"$CERT_TYPE\", webmaster_mail=\"$WEBMASTER_MAIL\", dsbase_version=\"$DSBASE_VERSION\", node_id=\"$NODE_ID\", node_name=\"$NODE_NAME\"} 1" > /etc/node-exporter/node_env_var.prom


set -- /bin/node_exporter "$@"

exec "$@"

