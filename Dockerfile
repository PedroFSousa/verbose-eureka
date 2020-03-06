FROM prom/prometheus

USER root

COPY prometheus/prometheus.yml /etc/prometheus/prometheus.yml

COPY ./docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD        [ "/bin/prometheus", \
             "--config.file=/etc/prometheus/prometheus.yml", \
             "--storage.tsdb.path=/prometheus", \
             "--web.console.libraries=/usr/share/prometheus/console_libraries", \
             "--storage.tsdb.retention.time=24h", \
             "--web.console.templates=/usr/share/prometheus/consoles" ]
