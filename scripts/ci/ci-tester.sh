#!/bin/bash

set -e

wait_for_service () {
  res=500
  echo "Waiting for $1 to be ready..."
  while [ $res != 200 ]
  do
    res=$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost/$2")
    sleep 5
  done
  echo -e "$1 is ready!\n"
}

BUILDS_DIR=/home/travis/build/
TESTER_NAME=coral-tester
DIST_NAME=PedroFSousa/verbose-eureka
TESTER_DIR=$BUILDS_DIR/$TESTER_NAME
DIST_DIR=$BUILDS_DIR/$DIST_NAME

cd $BUILDS_DIR

# Install requirements
rm -rf coral-tester

add-apt-repository -y ppa:deadsnakes/ppa
apt-get update
sudo apt install build-essential -y
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
apt-get install python python3.6 python3.6-dev python3-pip curl libffi-dev
apt -y install curl dirmngr apt-transport-https lsb-release ca-certificates
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
apt-get install -y nodejs

pip3 install --upgrade pip

git clone -b dev https://$DOCKER_LOGIN_USER:$DOCKER_LOGIN_PW@gitlab.inesctec.pt/coral/coral-tester.git

# Docker Registry Login
docker login -u $DOCKER_LOGIN_USER -p $DOCKER_LOGIN_PW docker-registry.inesctec.pt

cd $DIST_DIR

#Create Secrets
docker swarm init

# To add a worker to this swarm, run the following command:

# docker swarm join --token SWMTKN-1-2rhyr0f27a3l9z6yv7fzdwy1srl660lbygij3joqm7cs8zjzfk-elljnm9uxsd08tbvuzvpsn6q7 10.30.2.169:2377

# To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

secrets=( "AGATE_ADMINISTRATOR_PASSWORD" "OPAL_ADMINISTRATOR_PASSWORD" "MICA_ADMINISTRATOR_PASSWORD" "DRUPAL_ADMINISTRATOR_PASSWORD" "MYSQLIDS_PASSWORD" "MYSQLIDS_ROOT_PASSWORD" "MYSQLDATA_PASSWORD" "MYSQLDATA_ROOT_PASSWORD" "MYSQLDRUPAL_ROOT_PASSWORD" "MONGO_INITDB_ROOT_PASSWORD" )

for i in "${secrets[@]}"
do
  python3.6 -c "from lib.util.swarmadmin import create_secret; create_secret('password', '$i', 'system=Coral')"
done

# Deploy Coral
python3.6 coral.py --deploy --domain localhost --email test@test.com --test

echo -e "Waiting for Coral to be ready...\n"

sleep 60
wait_for_service "Agate" "/auth"
wait_for_service "Opal" "/repo/ui/index.html"
wait_for_service "Mica" "/pub"
wait_for_service "Mica-Drupal" "/cat"

echo -e "Coral is ready!\n"
echo "Iniciating tests..."

cd $TESTER_DIR

sudo npm install
sudo npm start

if [ $? == 0 ]; then
  echo -e "All tests were successfully completed!\n"
else
  echo -e "Tests failed!\n"
  exit 1
fi
