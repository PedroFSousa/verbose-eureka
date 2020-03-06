#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-opal
#

# Get passwords from secrets
if [ -n "$OPAL_ADMINISTRATOR_PASSWORD_FILE" ]; then
	OPAL_ADMINISTRATOR_PASSWORD=$(cat /run/secrets/OPAL_ADMINISTRATOR_PASSWORD)
fi

if [ -n "$MYSQLDATA_PASSWORD_FILE" ]; then
	MYSQLDATA_PASSWORD=$(cat /run/secrets/MYSQLDATA_PASSWORD)
fi

if [ -n "$MYSQLIDS_PASSWORD_FILE" ]; then
	MYSQLIDS_PASSWORD=$(cat /run/secrets/MYSQLIDS_PASSWORD)
fi

# Make sure conf folder is available
if [ ! -d $OPAL_HOME/conf ]; then
  mkdir -p $OPAL_HOME/conf
  cp -r $OPAL_DIR/conf/* $OPAL_HOME/conf
fi

# Configure administrator password
echo -n "Saving OPAL_ADMINISTRATOR_PASSWORD in $OPAL_HOME/conf/shiro.ini... "
adminpw=$(echo -n $OPAL_ADMINISTRATOR_PASSWORD | xargs java -jar $OPAL_DIR/tools/lib/obiba-password-hasher-*-cli.jar) && \
sed -i "s,^administrator\s*=.*\,,administrator=$adminpw\,," $OPAL_HOME/conf/shiro.ini && \
echo "Done!"

# Check if 1st run. Then configure Agate and Rserve
if [ ! -f $OPAL_HOME/first_run.sh.done ]; then
  cp $OPAL_DIR/conf/opal-config.properties /tmp/

  echo -n "Configuring Agate and Rserve... "
  if [ -n "$AGATE_PORT_8444_TCP_ADDR" ]; then
    sed -i s/localhost:8444/$AGATE_PORT_8444_TCP_ADDR:$AGATE_PORT_8444_TCP_PORT/g /tmp/opal-config.properties
    sed -i s/#org.obiba.realm.url/org.obiba.realm.url/g /tmp/opal-config.properties
  fi

  if [ -n "$RSERVER_PORT_6312_TCP_ADDR" ]; then
    sed -i s/#org.obiba.opal.Rserve.host=/org.obiba.opal.Rserve.host=$RSERVER_PORT_6312_TCP_ADDR/g /tmp/opal-config.properties
  fi

  if [ -n "$RSERVER_PORT_6312_TCP_PORT" ]; then
    sed -i s/#org.obiba.rserver.port=.*/org.obiba.rserver.port=$RSERVER_PORT_6312_TCP_PORT/g /tmp/opal-config.properties
  fi

  mv -f /tmp/opal-config.properties $OPAL_HOME/conf/ && \
  echo "Done!" || \
  echo "Failed to save Opal configuration in $OPAL_HOME/conf/opal-config.properties."
else
  echo "Skipping Agate and Rserve configuration..."
fi

# Set maximum memory allocated to Opal
if [ -n "$OPAL_JAVA_MEM" ]; then
  JAVA_OPTS=$(echo $JAVA_OPTS | sed "s/ -Xmx.*G / -Xmx${OPAL_JAVA_MEM}G /g")
fi

# Start Opal and configure databases if 1st run
echo "Starting Opal..."
if [ ! -f $OPAL_HOME/first_run.sh.done ]; then
  # Check if 1st run. Then configure databases
	$OPAL_DIR/bin/opal &

	# Wait for the Opal server to be up and running
	echo "Waiting for Opal to be ready before configuring/updating databases..."
	until opal rest -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD -m GET /system/databases &> /dev/null;	do
	  sleep 5
	done

  echo "Configuring databases..."
  source /opt/opal/bin/first_run.sh
  cp /opt/opal/bin/first_run.sh $OPAL_HOME/first_run.sh.done
else
  echo "Skipping first-run configuration..."
	$OPAL_DIR/bin/opal &
fi

# Run custom script and configure datashield packages
if [ -n "$RSERVER_PORT_6312_TCP_ADDR" ]; then
	echo "Waiting for Opal to be ready before configuring DataSHIELD and running custom script..."
  until opal rest -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD -m GET /system/databases &> /dev/null;	do
	  sleep 5
	done

  echo "Initializing DataSHIELD..."
	opal rest -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD -m POST /datashield/packages?name=dsBase&ref=$DSBASE_VERSION

  /opt/opal/bin/custom.sh
fi

tail -f $OPAL_HOME/logs/opal.log
