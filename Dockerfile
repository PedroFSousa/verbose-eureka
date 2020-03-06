FROM obiba/mica-drupal:35.1

# Disable server signature
RUN echo "ServerSignature Off" >> /etc/apache2/apache2.conf; \
  echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

# Install PHP 7.3.11
ENV PHP_VERSION=7.3.11
ENV PHP_URL=https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz
ENV PHP_SHA256=657cf6464bac28e9490c59c07a2cf7bb76c200f09cfadf6e44ea64e95fa01021

RUN /bin/sh -c set -xe; \
  fetchDeps='wget'; \
  if ! command -v gpg > /dev/null; then fetchDeps="$fetchDeps dirmngr gnupg"; fi; \
  apt-get update; \
  apt-get install -y --no-install-recommends $fetchDeps

RUN  mkdir -p /usr/src; \
  cd /usr/src; \
  wget -O php.tar.xz "$PHP_URL"; \
  if [ -n "$PHP_SHA256" ]; then echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; fi

RUN /bin/sh -c set -eux; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get update; \
  apt-get install -y --no-install-recommends libcurl4-openssl-dev libedit-dev libsqlite3-dev libssl-dev libxml2-dev zlib1g-dev ${PHP_EXTRA_BUILD_DEPS:-} libpng-dev libzip-dev libpq-dev; \
  rm -rf /var/lib/apt/lists/*; \
  export CFLAGS="$PHP_CFLAGS" CPPFLAGS="$PHP_CPPFLAGS" LDFLAGS="$PHP_LDFLAGS"

RUN docker-php-source extract; \
  cd /usr/src/php; \
  gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
  ./configure --build="$gnuArch" --with-config-file-path="$PHP_INI_DIR" --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" --enable-option-checking=fatal --with-mhash --enable-ftp --enable-mbstring --enable-mysqlnd --with-curl --with-libedit --with-openssl --with-zlib $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') --with-libdir="lib/$debMultiarch" ${PHP_EXTRA_CONFIGURE_ARGS:-} --with-gd --enable-zip --with-pdo-mysql; \
  make -j "$(nproc)"; \
  find -type f -name '*.a' -delete; \
  make install; \
  find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
  make clean; \
  cp -v php.ini-* "$PHP_INI_DIR/"; \
  cd /; \
  docker-php-source delete; \
  apt-mark auto '.*' > /dev/null

RUN [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
  find /usr/local -type f -executable -exec ldd '{}' ';' | awk '/=>/ { print $(NF-1) }' | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u | xargs -r apt-mark manual; \
  php --version; \
  pecl update-channels; \
  rm -rf /tmp/pear ~/.pearrc

#RUN docker-php-ext-install -j$(nproc) pdo_mysql pdo_pgsql gd zip opcache

# Comment out extensions that are already compiled in
RUN ls /usr/local/etc/php/conf.d | grep docker | xargs -I {} sed -i -e 's/^/;/' /usr/local/etc/php/conf.d/{}

# Copy custom files
ENV DRUPAL_DIR=/var/www/html

COPY ./scripts/wait-for-it.sh /
COPY ./scripts/disable_anonymous_stats.sql /
COPY ./Makefile /tmp/obiba-home-master/drupal/

COPY bin /opt/mica/bin
RUN mkdir /modules

# Install rsync, wget and git
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install rsync wget git

# Download all dependencies to avoid the need for internet access at run time
# Cannot download directly into /var/www/html because of 'VOLUME /var/www/html' in parent image
# Contents of /downloads are copied to /var/www/html with rsync at run time
RUN drush dl -y bootstrap-7.x-3.22 --destination=/downloads/themes && \
  drush dl -y autologout devel jquery_update variable libraries i18n http_client countries collapsiblock composer_manager entity --destination=/downloads/modules

RUN composer require flow/jsonpath erusev/parsedown && \
  mv $DRUPAL_DIR/vendor /downloads/

RUN cd /tmp && \
  curl -Ls https://github.com/obiba/mica-drupal-js-libraries/archive/$MICA_JS_VERSION.tar.gz | tar -xzf - && \
  mv mica-drupal-js-libraries-$MICA_JS_VERSION /downloads/libraries

COPY ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["app"]
