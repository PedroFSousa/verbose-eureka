#!/bin/bash

if [ "$1" != "agate" -a "$1" != "opal" -a "$1" != "mica" ]; then
  echo "ERROR: unknown application '$1'. Must be one of: agate, opal, mica."
  exit 1
fi

agate_js_path=$AGATE_DIR/webapp/dist/scripts/scripts.js
agate_route=/auth/

opal_js_path=$OPAL_DIR/webapp/ui/ui.nocache.js
opal_route=/repo

mica_js_path=$MICA_DIR/webapp/dist/scripts/scripts.js
mica_route=/pub/

js_code_tmp="var open=window.XMLHttpRequest.prototype.open;function opRp(method,url,async,user,password){var mod_url='APP_ROUTE'+url.replace('/ws','ws');arguments[1]=mod_url;return open.apply(this,arguments);}window.XMLHttpRequest.prototype.open=opRp;"

if [ "$1" == "agate" ]; then
  js_path=$agate_js_path
  route=$agate_route
elif [ "$1" == "opal" ]; then
  js_code_tmp=$(echo $js_code_tmp | sed "s|.replace('/ws','ws')||")
  js_path=$opal_js_path
  route=$opal_route
else
  js_path=$mica_js_path
  route=$mica_route
fi

js_code=$(echo $js_code_tmp | sed "s|APP_ROUTE|$route|g")

# fix path of requests for mica editor themes (not caugth by XMLHttpRequest.open)
if [ "$1" == "mica" ]; then
  sed -i "s|Path\",\"/scripts|Path\",\"${route}scripts|g" $js_path
fi

sed -i "1s|^|$js_code|" $js_path && \
echo "$1 route was set to '$route'"
