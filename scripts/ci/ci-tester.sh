#!/bin/bash

set -e

wait_for_service () {
  res=500
  echo "Waiting for $1 to be ready..."
  while [ $res != 200 ]
  do
    res=$(curl -k -s -o /dev/null -w "%{http_code}" "https://docker/$2")
    sleep 5
  done
  echo -e "$1 is ready!\n"
}

# BUILDS_DIR=/builds/coral
# TRAVIS CI home dir
BUILDS_DIR=/home/travis/build/
TESTER_NAME=coral-tester
# DIST_NAME=coral-docker-dist
# TRAVIS CI test dist dir
DIST_NAME=PedroFSousa/verbose-eureka
TESTER_DIR=$BUILDS_DIR/$TESTER_NAME
DIST_DIR=$BUILDS_DIR/$DIST_NAME

cd $BUILDS_DIR

# Install requirements
rm -rf coral-tester
# travis doesnt recognise apk or --no-cache
# apt add --no-cache python python3 python3-dev py3-pip curl build-base libffi-dev openssl-dev libgcc
# apt add --update nodejs npm

apt install python python3 python3-dev py3-pip curl build-base libffi-dev openssl-dev libgcc
# apt-get --update nodejs npm
# dont know if i can remove both lines above

pip3 install --upgrade pip
pip3 install docker-compose

# cd $BUILDS_DIR

git clone https://gitlab-ci-token:$CI_JOB_TOKEN@gitlab.inesctec.pt/coral/coral-tester.git

# Docker Registry Login
docker login -u gitlab-ci-token -p $CI_JOB_TOKEN docker-registry.inesctec.pt

cd $DIST_DIR

#Create Secrets
docker swarm init

secrets=( "AGATE_ADMINISTRATOR_PASSWORD" "OPAL_ADMINISTRATOR_PASSWORD" "MICA_ADMINISTRATOR_PASSWORD" "DRUPAL_ADMINISTRATOR_PASSWORD" "MYSQLIDS_PASSWORD" "MYSQLIDS_ROOT_PASSWORD" "MYSQLDATA_PASSWORD" "MYSQLDATA_ROOT_PASSWORD" "MYSQLDRUPAL_ROOT_PASSWORD" "MONGO_INITDB_ROOT_PASSWORD" )

for i in "${secrets[@]}"
do
  python3 -c "from lib.util.swarmadmin import create_secret; create_secret('password', '$i', 'system=Coral')"
done

# Deploy Coral
python3 coral.py --deploy --domain localhost --email test@test.com --test

echo -e "Waiting for Coral to be ready...\n"

sleep 60
wait_for_service "Agate" "/auth"
wait_for_service "Opal" "/repo/ui/index.html"
wait_for_service "Mica" "/pub"
wait_for_service "Mica-Drupal" "/cat"

echo -e "Coral is ready!\n"
echo "Iniciating tests..."

cd $TESTER_DIR

npm install
npm start

if [ $? == 0 ]; then
  echo -e "All tests were successfully completed!\n"
else
  echo -e "Tests failed!\n"
  exit 1
fi
