#!/bin/bash

# Enable user namesapces
# unprivileged_userns_clone=$(cat /proc/sys/kernel/unprivileged_userns_clone)
# if [ "$max_user_namespaces" -ne 1 ]; then
# 	info "Enabling user namespaces..."
# 	echo "kernel.unprivileged_userns_clone=1" >> /etc/sysctl.conf && \
# 	sysctl -p || \
# 	err "Could not enable user namespaces."
# else
# 	info "User namespaces already enabled."
# fi
#
# echo "DOCKER_OPTS=--userns-remap=default" >> /etc/default/docker -> does not work
# userns-remap and data-root must be set in /etc/docker/daemon.json

# Update all packages on the system
info "Updating all packages..."
apt-get update

# Install required packages
info "Installing required packages..."
apt-get install -yf curl apt-transport-https ca-certificates software-properties-common gnupg || \
err "Failed to install required packages."

#	Add Docker CE repo
info "Adding Docker CE repo..."
curl -fsSL https://download.docker.com/linux/$os/gpg | apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$os $(lsb_release -cs) stable" || \
err "Failed to add Docker CE repo."

# Install Python 3.6
info "Installing Python 3.6..."
if [ "$os" = "ubuntu" ]; then
  add-apt-repository -y ppa:deadsnakes/ppa
  apt-get update
  apt-get install -yf build-essential libssl-dev libffi-dev python3.6 python3.6-dev python3-setuptools || \
  err "Failed to configure Python 3.6."
elif [ "$os" = "debian" ]; then
  python_version=3.6.9
  apt-get update
  apt-get install -y libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev
  cd /usr/src
  curl https://www.python.org/ftp/python/${python_version}/Python-${python_version}.tgz -o Python-${python_version}.tgz
  tar xzf Python-${python_version}.tgz
  cd Python-${python_version}/
  ./configure --enable-optimizations
  make altinstall
fi

# Remove older versions of Docker
info "Removing older Docker versions..."
apt-get remove docker docker-engine docker.io containerd runc

# Install Docker CE
info "Installing Docker CE..."
apt-get install -y docker-ce || \
err "Failed to install Docker CE."

# Install docker-compose
info "Installing Docker Compose..."
apt-get install -yf python3-pip && \
LC_ALL=C python3.6 -m pip install wheel && \
LC_ALL=C python3.6 -m pip install setuptools pyyaml docker-compose && \
info "Docker Compose is installed." || \
err "Failed to install Docker Compose."

# Add current user to the docker group
groupadd docker || true
gpasswd -a $SUDO_USER docker

chown -R :docker /var/lib/docker/volumes
chmod -R 0774 /var/lib/docker/volumes
