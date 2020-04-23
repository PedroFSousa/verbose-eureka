#!/bin/bash

err () {
  echo "ERROR: $1"
  exit 1
}

# $1: response object; $2: expected status code; $3: msg in case of error
check_status () {
  STATUS=$(echo "$1" | grep "status_code" | cut -d'=' -f2)

  [ $STATUS -ne $2 ] &&  \
  err "$3 - $1"
}

BUILDS_DIR=/home/travis/build/
# PROJECT_DIR=$BUILDS_DIR/$CI_PROJECT_NAMESPACE
# PROJECT_DIR=$TRAVIS_BUILD_DIR
# DIST_DIR=$PROJECT_DIR/$CI_PROJECT_NAME
DIST_DIR=$TRAVIS_BUILD_DIR
VERSION=$1
ZIP_NAME=verbose-eureka.zip
# testing new URL
DEPLOYMENT_SERVICE_URL=https://recap-monitor.inesctec.pt

# Install dependencies
apt-get install git curl

cd $DIST_DIR

# set version number in settings
echo "Setting Coral version in settings.py..."
sed -i s/\<coral_version\>/$VERSION/g lib/settings.py
stash=$(git stash create)

# empty apache/custom.conf
echo "# Custom Apache configuration" > custom/apache/conf/custom.conf

# create zip file and checksum artifacts
echo "Generating ZIP file and checksum..."
mkdir artifacts

git archive --prefix=verbose-eureka_$VERSION/ -o artifacts/$ZIP_NAME $stash
CHECKSUM=$(md5sum artifacts/$ZIP_NAME | cut -c -32)
echo $CHECKSUM > artifacts/verbose-eureka-checksum.txt

echo "//////////////////////////////////////////"
echo $TRAVIS_REPO_SLUG
echo $TRAVIS_JOB_NAME
echo $TRAVIS_COMMIT_MESSAGE
echo $GITHUB_REPOSITORY
echo "//////////////////////////////////////////"

# publish new version on the deployment page
echo "Publishing version $VERSION..."
echo $DEPLOYMENT_EMAIL
# get access token
RES=$(curl -s -k -X POST \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEPLOYMENT_EMAIL\",\"password\":\"$DEPLOYMENT_PASSWORD\"}" \
  -w "\nstatus_code=%{http_code}\n" \
  "${DEPLOYMENT_SERVICE_URL}/api/users/login")

check_status "$RES" 200 "unable to login"

ACCESS_TOKEN=$(echo "$RES" | grep -Po '"id":.*?[^\\]",' | cut -d'"' -f4)

[ -z "$ACCESS_TOKEN" ] && \
err "could not get access token - $RES"

# post the zip and md files to the deployment service
RES=$(curl -v -k -X POST \
  -H "Content-Type: multipart/form-data" \
  -H "Connection: keep-alive" \
  -F "md=@README.md" \
  -F "zip=@artifacts/$ZIP_NAME" \
  -w "\nstatus_code=%{http_code}\n" \
  "${DEPLOYMENT_SERVICE_URL}/api/files/upload?version=${VERSION}&checksum=${CHECKSUM}&access_token=${ACCESS_TOKEN}")

check_status "$RES" 200 "could not upload zip/md files"

# logout
curl -k -X DELETE "${DEPLOYMENT_SERVICE_URL}/api/users/logout?access_token=${ACCESS_TOKEN}"

echo "Done!"
