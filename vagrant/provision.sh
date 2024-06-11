#!/bin/bash

set -x

export DEBIAN_FRONTEND=noninteractive
ARCH="$(dpkg --print-architecture)"

apt-get update
apt-get --yes upgrade
apt-get --yes install apt-transport-https

echo "export EDITOR=vim" >> /home/vagrant/.bashrc

# Install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker vagrant

# Install make
apt-get install -y make

# install requirements for ruby
apt install -y \
   gcc \
   g++ \
   libsnappy-dev \
   libicu-dev \
   zlib1g-dev \
   cmake \
   pkg-config \
   libssl-dev \
   ruby-dev \
   ruby-bundler
