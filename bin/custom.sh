#!/bin/bash

# Update a Mica form
update_form () {
	if [ -f $MICA_DIR/forms/individual-studies/$1.json ]; then
		mica rest "/config/$1/form-custom" -v -m PUT -mk https://localhost:8445 -ct "application/json;charset=utf-8" -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD" < "$MICA_DIR/forms/individual-studies/$1.json" && \
		echo "Updated forms: $1.json"
	else
		echo "No form found for $1"
	fi
}

# Wait for Mica to start
echo "Waiting for Mica to be ready before updating forms..."
until (mica rest "/config" -m GET -mk https://localhost:8445 -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD" > /dev/null); do
	sleep 5
done

# Update study/population/DCE forms
echo "Updating study/population/DCE forms..."
forms=( "individual-study" "population" "data-collection-event" )
for form in "${forms[@]}"; do	update_form $form; done

# Update search criteria
echo "Updating search criteria..."
if [ -f $MICA_DIR/forms/search-criteria/mica_search_criteria.json ]; then
	mica rest "/config/study/taxonomy" -v -m PUT -mk https://localhost:8445 -ct "application/json;charset=utf-8" -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD" < "$MICA_DIR/forms/search-criteria/mica_search_criteria.json" && \
	echo "Updated search criteria: mica_search_criteria.json"
else
		echo "No custom search criteria found"
fi

# Add custom Opal credentials
echo "Adding Opal credentials..."
creds=$(find $MICA_DIR/opal_creds -type f -name "*.json")

if [ "$creds" ]; then
	for f in $creds; do
		creds_json=$(cat $f)
		# grep -P '"opalUrl".*"https://opal:8443",' $f > /dev/null && grep -P '"username".*"administrator",' $f > /dev/null && f=$(sed "s/INSERT_PASSWORD/$OPAL_ADMINISTRATOR_PASSWORD/g" $f)
		grep -P '"opalUrl".*"https://opal:8443",' $f > /dev/null && grep -P '"username".*"administrator",' $f > /dev/null && creds_json=$(sed "s/INSERT_PASSWORD/$OPAL_ADMINISTRATOR_PASSWORD/g" $f)
		echo $creds_json | mica rest /config/opal-credentials -v -m POST -mk https://localhost:8445 -ct "application/json;charset=utf-8" -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD" && \
		echo "Added Opal credentials from file $(basename $f)"
	done
else
	echo "No Opal credentials found"
fi

# Grant 'Reader' perms to the mica-reader group on Mica documents
mica_docs=( "network" "individual-study" "harmonization-study" "collected-dataset" "harmonized-dataset" "project" "data-access-form" )
for doc in "${mica_docs[@]}"; do
	mica rest "/config/$doc/permissions?principal=mica-reader&role=READER&type=GROUP" -m PUT -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD" -mk https://localhost:8445
done
echo "Granted 'Reader' perms to the mica-reader group on Mica documents"

# Re-index taxonomies
#mica rest /cache/micaConfig -m DELETE -v -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD" -mk https://localhost:8445
mica rest "/config/_index" -m PUT -mk https://localhost:8445 -u administrator -p "$MICA_ADMINISTRATOR_PASSWORD"
