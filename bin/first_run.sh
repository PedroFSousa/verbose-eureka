#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-agate
#

# Configure MongoDB
if [ -n "$MONGO_PORT_27017_TCP_ADDR" ]; then
  cp $AGATE_DIR/conf/application.yml /tmp/

  echo -n "Configuring MongoDB... "
  if [ -n "$MONGO_INITDB_ROOT_USERNAME" -a -n "$MONGO_INITDB_ROOT_PASSWORD" ]; then
	  sed -i "s/localhost:27017\/agate/$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT\/agate?authSource=admin/g" /tmp/application.yml
  else
    sed -i s/localhost:27017/$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT/g /tmp/application.yml
  fi
  [ $? -eq 0 ] && echo "Done!"
fi

# Configure ReCaptcha
if [ -n "$RECAPTCHA_SITE_KEY" -a -n "$RECAPTCHA_SECRET_KEY" ]; then
  echo -n "Configuring reCAPTCHA keys... "
  sed -i s/secret:\ 6Lfo7gYT.*/secret:\ $RECAPTCHA_SECRET_KEY/ /tmp/application.yml && \
	sed -i s/reCaptchaKey:.*/reCaptchaKey:\ $RECAPTCHA_SITE_KEY/ /tmp/application.yml && \
  echo "Done!"
fi

mv -f /tmp/application.yml $AGATE_HOME/conf/ && \
echo "Agate configuration complete." || \
echo "Failed to save Agate configuration in $AGATE_HOME/conf/application.yml."

# Create custom apps/groups
source /opt/agate/bin/custom.sh &
