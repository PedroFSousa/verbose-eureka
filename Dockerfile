FROM docker-registry.inesctec.pt/csig-all/apache-with-certificate:3.2.0

COPY conf /etc/apache2/conf-available
COPY html /var/www/html
COPY scripts /etc/apache2/scripts

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
