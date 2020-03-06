#!/bin/bash

# Configure site name
drush variable-set -y site_name "$SITE_NAME"

# Configure footer credit
if [ -n "$FOOTER_CREDIT" ]; then
  sed -i "s|Powered by|$(eval echo $FOOTER_CREDIT) Powered by|g" $DRUPAL_DIR/sites/all/modules/obiba_mica/obiba_mica.module && \
  echo "Footer credit was changed"
fi

# Copy modified Drupal files, if any
if [ -d "/sites" ]; then
  echo "Synching Drupal files in /var/www/html/sites with /sites..."
  rsync -ir /sites $DRUPAL_DIR/
fi

# Enable any custom modules in /modules
custom_modules=$(find /modules -mindepth 1 -maxdepth 1 -type d -exec bash -c "basename {}" \;)
if [ "$custom_modules" ]; then
	for m in $custom_modules; do
    cp -r /modules/$m $DRUPAL_DIR/sites/all/modules/
		drush en -y $m
	done
  #drush cc all
else
	echo "No custom modules found"
fi

if [ "$ALLOW_ANONYMOUS_STATS" == "no" ]; then
  # Download and enalbe custom_menu_perms module
  curl https://ftp.drupal.org/files/projects/custom_menu_perms-7.x-1.0.tar.gz --output custom_menu_perms-7.x-1.0.tar.gz
  tar -xvf custom_menu_perms-7.x-1.0.tar.gz -C $DRUPAL_DIR/modules
  chown -R www-data:www-data $DRUPAL_DIR/modules/custom_menu_perms
  # Fix bug in custom_menu_perms install script
  sed -i -e ':a;N;$!ba;s/255,\n\t\t\t)/255,\n\t\t\t\t'\''not null'\'' => TRUE,\n\t\t\t)/' $DRUPAL_DIR/modules/custom_menu_perms/custom_menu_perms.install
  # Enable custom_menu_perms module in Drupal
  drush en -y custom_menu_perms

  # Disable anonymous access to variable statistics
  mysql -h $MYSQL_PORT_3306_TCP_ADDR -u root -p$MYSQL_ROOT_PASSWORD drupal_mica < /disable_anonymous_stats.sql && \
  echo "Anonymous access to variable statistics is disabled"
fi 

chown -R www-data:www-data $DRUPAL_DIR

# Run SQL customization script
if [ -f "/customize.sql" ]; then
  mysql -h $MYSQL_PORT_3306_TCP_ADDR -u root -p$MYSQL_ROOT_PASSWORD drupal_mica < /customize.sql
fi

# Run Shell customization script
if [ -f "/customize.sh" ]; then
  source /customize.sh
fi

# Clear all Drupal cache and rebuild menu
drush cc all
drush eval 'menu_rebuild();'
