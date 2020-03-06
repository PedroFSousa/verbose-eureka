#!/bin/bash
#
# Adapted from https://github.com/obiba/docker-opal
#

if [ -n "$MYSQLIDS_PORT_3306_TCP_ADDR" ]; then
	echo "Initializing Opal IDs database with MySQL..."

	MID_DB="opal"
	if [ -n "$MYSQLIDS_DATABASE" ]; then
		MID_DB=$MYSQLIDS_DATABASE
	fi

	MID_USER="root"
	if [ -n "$MYSQLIDS_USER" ]; then
		MID_USER=$MYSQLIDS_USER
	fi

	sed s/@mysql_host@/$MYSQLIDS_PORT_3306_TCP_ADDR/g /opt/opal/data/mysqldb-ids-tabular.json | \
  sed s/@mysql_port@/$MYSQLIDS_PORT_3306_TCP_PORT/g | \
  sed s/@mysql_db@/$MID_DB/g | \
  sed s/@mysql_user@/$MID_USER/g | \
  sed s/@mysql_pwd@/$MYSQLIDS_PASSWORD/g | \
  opal rest -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD -m POST /system/databases --content-type "application/json"
fi

if [ -n "$MYSQLDATA_PORT_3306_TCP_ADDR" ];then
	echo "Initializing Opal data database with MySQL..."

	MD_DB="opal"
	if [ -n "$MYSQLDATA_DATABASE" ]; then
		MD_DB=$MYSQLDATA_DATABASE
	fi

	MD_USER="root"
	if [ -n "$MYSQLDATA_USER" ]; then
		MD_USER=$MYSQLDATA_USER
	fi

	MD_DEFAULT="true"

	sed s/@mysql_host@/$MYSQLDATA_PORT_3306_TCP_ADDR/g /opt/opal/data/mysqldb-data.json | \
	sed s/@mysql_port@/$MYSQLDATA_PORT_3306_TCP_PORT/g | \
	sed s/@mysql_db@/$MD_DB/g | \
	sed s/@mysql_user@/$MD_USER/g | \
	sed s/@mysql_pwd@/$MYSQLDATA_PASSWORD/g | \
	sed s/@mysql_default@/$MD_DEFAULT/g | \
	opal rest -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD -m POST /system/databases --content-type "application/json"
fi

# Create opal-administrator and opal-create-project permission groups
opal rest "/system/permissions/administration?permission=SYSTEM_ALL&principal=opal-administrator&type=GROUP" -v -m POST -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD && \
opal rest "/system/permissions/administration?permission=PROJECT_ADD&principal=opal-create-project&type=GROUP" -v -m POST -o https://localhost:8443 -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD && \
echo "Created 'opal-administrator' and 'opal-create-project' permission groups" || \
echo "Failed to create 'opal-administrator' and/or 'opal-create-project' permission groups"
