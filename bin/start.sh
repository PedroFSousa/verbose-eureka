#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-agate
#

# Get passwords from secrets 
if [ -n "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
	MONGO_INITDB_ROOT_PASSWORD=$(cat /run/secrets/MONGO_INITDB_ROOT_PASSWORD)
fi

if [ -n "$AGATE_ADMINISTRATOR_PASSWORD_FILE" ]; then
	AGATE_ADMINISTRATOR_PASSWORD=$(cat /run/secrets/AGATE_ADMINISTRATOR_PASSWORD)
fi

# Make sure conf folder is available
if [ ! -d $AGATE_HOME/conf ];	then
	mkdir -p $AGATE_HOME/conf
	cp -r $AGATE_DIR/conf/* $AGATE_HOME/conf
fi

# Configure administrator password
echo -n "Saving AGATE_ADMINISTRATOR_PASSWORD in $AGATE_HOME/conf/shiro.ini... "
adminpw=$(echo -n $AGATE_ADMINISTRATOR_PASSWORD | xargs java -jar $AGATE_DIR/tools/lib/obiba-password-hasher-*-cli.jar) && \
sed -i "s,^administrator\s*=.*\,,administrator=$adminpw\,," $AGATE_HOME/conf/shiro.ini && \
echo "Done!"

# Check if 1st run. Then configure application
if [ ! -f $AGATE_HOME/first_run.sh.done ]; then
  echo "Configuring Agate..."
	source /opt/agate/bin/first_run.sh
  cp /opt/agate/bin/first_run.sh $AGATE_HOME/first_run.sh.done
else
  echo "Skipping first-run configuration..."
fi

# Wait for MongoDB to be ready
if [ -n "$MONGO_PORT_27017_TCP_ADDR" ];	then
	until curl -u $MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD -i http://$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT/agate &> /dev/null;	do
  	sleep 1
	done
fi

# Start agate
echo "Starting Agate..."
$AGATE_DIR/bin/agate
