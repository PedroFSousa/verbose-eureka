#!/bin/bash

# Add/update custom taxonomies
echo "Adding/updating custom taxonomies..."

taxonomies=$(find $OPAL_DIR/taxonomies -type f -name "*.json")

if [ "$taxonomies" ]; then
  for f in $taxonomies; do
		taxonomy_name=$(basename $f | sed s/\.json$//g)
		opal rest /system/conf/taxonomy/$taxonomy_name -m GET -o https://localhost:8443 -u administrator -p "$OPAL_ADMINISTRATOR_PASSWORD" > /dev/null && \
		taxonomy_exists=1 || \
		taxonomy_exists=

		if [ -n "$taxonomy_exists" ]; then
			opal rest /system/conf/taxonomy/$taxonomy_name -m PUT -o https://localhost:8443 -ct application/json -u administrator -p "$OPAL_ADMINISTRATOR_PASSWORD" < $f && \
			echo "Updated custom taxonomy: $taxonomy_name" || \
			echo "Failed to update custom taxonomy: $taxonomy_name"
		else
			opal rest /system/conf/taxonomies -m POST -o https://localhost:8443 -ct application/json -u administrator -p "$OPAL_ADMINISTRATOR_PASSWORD" < $f && \
			echo "Added new custom taxonomy: $taxonomy_name" || \
			echo "Failed to create new custom taxonomy: $taxonomy_name"
		fi
	done
  #find $OPAL_DIR/taxonomies -type f -name "*.json" -exec bash -c "opal rest /system/conf/taxonomies -v -m POST -o https://localhost:8443 -ct application/json -u administrator -p $OPAL_ADMINISTRATOR_PASSWORD < {}" \;
else
	echo "No custom taxonomies found"
fi
