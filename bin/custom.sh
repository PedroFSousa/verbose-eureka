#!/bin/bash

# Wait for Agate to start
until (agate rest "/applications" -m GET -ag https://localhost:8444 -u administrator -p "$AGATE_ADMINISTRATOR_PASSWORD" > /dev/null); do
	sleep 5
done

# Create custom applications and groups
echo "Creating custom applications and groups..."
apps=$(find $AGATE_DIR/applications -type f -name "*.json")
groups=$(find $AGATE_DIR/groups -type f -name "*.json")

if [ "$apps" ]; then
	for f in $apps; do
		agate rest "/applications" -v -m POST -ag https://localhost:8444 -ct "application/json;charset=utf-8" -u administrator -p "$AGATE_ADMINISTRATOR_PASSWORD" < $f && \
		echo "Created custom application $(basename $f)"
	done
else
	echo "No custom applications found"
fi

if [ "$groups" ]; then
	for f in $groups; do
		agate rest "/groups" -v -m POST -ag https://localhost:8444 -ct "application/json;charset=utf-8" -u administrator -p "$AGATE_ADMINISTRATOR_PASSWORD" < $f && \
		echo "Created custom group $(basename $f)"
	done
else
	echo "No custom groups found"
fi
