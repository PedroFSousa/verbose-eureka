FROM obiba/mica:3.5

ENV MICA_DIR=/usr/share/mica2

COPY ./scripts/wait-for-it.sh /

COPY ./bin/ /opt/mica/bin/
RUN [ "/bin/bash", "-c", "mkdir -p $MICA_DIR/{forms,opal_creds}" ]

# Install mica-search-es plugin
ARG MICA_SEARCH_ES_VERSION=1.1.0
RUN set -x && \
  cd /tmp && \
  wget -q -O mica-search-es-dist.zip https://github.com/obiba/mica-search-es/releases/download/${MICA_SEARCH_ES_VERSION}/mica-search-es-${MICA_SEARCH_ES_VERSION}-dist.zip && \
  unzip -q mica-search-es-dist.zip -d ${MICA_HOME}/plugins && \
  rm mica-search-es-dist.zip

# Install Mica Python Client
RUN \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 379CE192D401AB61 && \
  echo 'deb https://dl.bintray.com/obiba/deb all main' | tee /etc/apt/sources.list.d/obiba.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mica-python-client

COPY ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["app"]
