#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica
#

# Configure MongoDB
if [ -n "$MONGO_PORT_27017_TCP_ADDR" ]; then
	cp $MICA_DIR/conf/application.yml /tmp/

  echo -n "Configuring MongoDB... "
	if [ -n "$MONGO_INITDB_ROOT_USERNAME" -a -n "$MONGO_INITDB_ROOT_PASSWORD" ]; then
	  sed -i "s/localhost:27017\/mica/$MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD@$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT\/mica?authSource=admin/g" /tmp/application.yml
	else
		sed -i s/localhost:27017/$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT/g /tmp/application.yml
	fi
	[ $? -eq 0 ] && echo "Done!"
fi

# Configure Opal address/port
echo -n "Configuring Opal and Agate connections... "
if [ -n "$OPAL_PORT_8443_TCP_ADDR" ]; then
	sed -i "s/localhost:8443/$OPAL_PORT_8443_TCP_ADDR:$OPAL_PORT_8443_TCP_PORT/g" /tmp/application.yml; opal_addr_status=$?
fi

# Configure Agate
if [ -n "$AGATE_PORT_8444_TCP_ADDR" ]; then
	sed -i "s/localhost:8444/$AGATE_PORT_8444_TCP_ADDR:$AGATE_PORT_8444_TCP_PORT/g" /tmp/application.yml; agate_status=$?
fi

[ $opal_addr_status -eq 0 ] && [ $agate_status -eq 0 ] && \
echo "Done!" || \
echo "Failed to configure Opal and/or Agate."

mv -f /tmp/application.yml $MICA_HOME/conf/ && \
echo "Mica configuration complete." || \
echo "Failed to save Mica configuration in $MICA_HOME/conf/application.yml."
