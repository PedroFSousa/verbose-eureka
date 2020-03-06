#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-mica
#

# Get passwords from secrets
if [ -n "$MICA_ADMINISTRATOR_PASSWORD_FILE" ]; then
	MICA_ADMINISTRATOR_PASSWORD=$(cat /run/secrets/MICA_ADMINISTRATOR_PASSWORD)
fi

if [ -n "$MONGO_INITDB_ROOT_PASSWORD_FILE" ]; then
	MONGO_INITDB_ROOT_PASSWORD=$(cat /run/secrets/MONGO_INITDB_ROOT_PASSWORD)
fi

if [ -n "$OPAL_ADMINISTRATOR_PASSWORD_FILE" ]; then
	OPAL_ADMINISTRATOR_PASSWORD=$(cat /run/secrets/OPAL_ADMINISTRATOR_PASSWORD)
fi

# Make sure conf folder is available
if [ ! -d $MICA_HOME/conf ]; then
	mkdir -p $MICA_HOME/conf
	cp -r $MICA_DIR/conf/* $MICA_HOME/conf
fi

# Configure administrator password
echo -n "Saving MICA_ADMINISTRATOR_PASSWORD in $MICA_HOME/conf/shiro.ini... "
adminpw=$(echo -n $MICA_ADMINISTRATOR_PASSWORD | xargs java -jar $MICA_DIR/tools/lib/obiba-password-hasher-*-cli.jar) && \
sed -i "s,^administrator\s*=.*\,,administrator=$adminpw\,," $MICA_HOME/conf/shiro.ini && \
echo "Done!"

# Configure anonymous password
echo -n "Saving MICA_ANONYMOUS_PASSWORD in $MICA_HOME/conf/shiro.ini... "
anonympw=$(echo -n $MICA_ANONYMOUS_PASSWORD | xargs java -jar $MICA_DIR/tools/lib/obiba-password-hasher-*-cli.jar) && \
sed -i "s,^anonymous\s*=.*,anonymous=$anonympw," $MICA_HOME/conf/shiro.ini && \
echo "Done!"

# Copy mica-taxonomy.yml to volume
echo -n "Updating mica-taxonomy.yml... "
cp $MICA_DIR/conf/taxonomies/mica-taxonomy.yml $MICA_HOME/conf/taxonomies/ && \
echo "Done!"

# Check if 1st run. Then configure application
if [ ! -f $MICA_HOME/first_run.sh.done ]; then
	echo "Configuring Mica..."
	source /opt/mica/bin/first_run.sh
  cp /opt/mica/bin/first_run.sh $MICA_HOME/first_run.sh.done
else
  echo "Skipping first-run configuration..."
fi

# Configure Opal password
echo -n "Configuring Opal password... "
if [ -n "$OPAL_ADMINISTRATOR_PASSWORD" ]; then
	sed -ri "s/password: .+/password: $OPAL_ADMINISTRATOR_PASSWORD/g" $MICA_HOME/conf/application.yml; opal_pwd_status=$?
fi

[ $opal_pwd_status -eq 0 ] && \
echo "Done!" || \
echo "Failed to configure Opal password."

# Wait for MongoDB to be ready
if [ -n "$MONGO_PORT_27017_TCP_ADDR" ]; then
	until curl -u $MONGO_INITDB_ROOT_USERNAME:$MONGO_INITDB_ROOT_PASSWORD -i http://$MONGO_PORT_27017_TCP_ADDR:$MONGO_PORT_27017_TCP_PORT/mica &> /dev/null; do
  	sleep 1
	done
fi

# Update study/population/DCE forms, search criteria, Opal credentials and perms for the mica-user group
source /opt/mica/bin/custom.sh &

# Start mica
echo "Starting Mica..."
$MICA_DIR/bin/mica2
