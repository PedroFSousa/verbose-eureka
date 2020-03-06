#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica-drupal
#

if [ -n "$MYSQL_ROOT_PASSWORD_FILE" ]; then
  MYSQL_ROOT_PASSWORD=$(cat /run/secrets/MYSQLDRUPAL_ROOT_PASSWORD)
fi

if [ -n "$DRUPAL_ADMINISTRATOR_PASSWORD_FILE" ]; then
  DRUPAL_ADMINISTRATOR_PASSWORD=$(cat /run/secrets/DRUPAL_ADMINISTRATOR_PASSWORD)
fi

# Configure database
if [ -n $MYSQL_PORT_3306_TCP_ADDR ]; then
  # Wait for MySQL to be ready
  until mysql -h $MYSQL_PORT_3306_TCP_ADDR -u root -p$MYSQL_ROOT_PASSWORD -e ";" &> /dev/null; do
    sleep 1
  done

  echo "Configuring database..."
  cd /tmp/obiba-home-master && \
  make -s import-sql-tables settings db_host=$MYSQL_PORT_3306_TCP_ADDR db_name=$MYSQL_DATABASE db_user=root db_pass=$MYSQL_ROOT_PASSWORD drupal_dir=$DRUPAL_DIR
fi

# Drupal settings
if [ ! -z $BASE_URL ]; then
  echo '$base_url = "'$BASE_URL'";' >> $DRUPAL_DIR/sites/default/settings.php && \
  echo "BASE_URL was set to: $BASE_URL"
fi

# Remove memory limit to prevent drush memory error
echo "ini_set('memory_limit', '-1');" >> $DRUPAL_DIR/sites/default/settings.php

# Move dependencies into place before configuring Drupal
echo "Moving dependencies into place..."
rsync -qir /downloads/themes/* $DRUPAL_DIR/sites/all/themes/
rsync -qir /downloads/modules/* $DRUPAL_DIR/sites/all/modules/
[ ! -d $DRUPAL_DIR/sites/all/vendor ] && mkdir $DRUPAL_DIR/sites/all/vendor; rsync -qir /downloads/vendor/* $DRUPAL_DIR/sites/all/vendor/
rsync -qir /downloads/libraries/* $DRUPAL_DIR/sites/all/libraries/

# Configure Drupal (requires database connection)
echo "Configuring Drupal..."
cd /tmp/obiba-home-master && \
  make enable-modules-snapshot drupal_dir=$DRUPAL_DIR mica_js_dependencies_branch=${MICA_JS_VERSION}

if [ -n "$MICA_PORT_8445_TCP_ADDR" ]; then
  cd $DRUPAL_DIR && \
  drush vset -y mica_url https://$MICA_PORT_8445_TCP_ADDR:$MICA_PORT_8445_TCP_PORT
fi

if [ -n "$AGATE_PORT_8444_TCP_ADDR" ]; then
  cd $DRUPAL_DIR && \
  drush vset -y agate_url https://$AGATE_PORT_8444_TCP_ADDR:$AGATE_PORT_8444_TCP_PORT
fi

# Set passwords
cd $DRUPAL_DIR && \
  drush upwd administrator --password=$DRUPAL_ADMINISTRATOR_PASSWORD && \
  drush vset -q -y mica_anonymous_password $MICA_ANONYMOUS_PASSWORD
  [ $? == 0 ] &&  echo "mica_anonymous_password was set." || \
  echo "Error setting mica_anonymous_password."
  chown -R www-data:www-data $DRUPAL_DIR

# Apply customisations
source /opt/mica/bin/custom.sh
