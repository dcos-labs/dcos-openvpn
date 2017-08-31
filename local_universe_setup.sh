#!/bin/bash

# Prerequisites
# Docker registry running and available by DC/OS
# docker run -d -p 5000:5000 --restart=always --name registry registry:2
# Docker daemon on each DC/OS node configured to work with insecure registry
# https://docs.docker.com/registry/insecure/ or secure your registry

function rebuild_universe {
  dcos config set core.dcos_url https://192.168.33.11
  dcos auth login --username=admin --password=password
  rm -rf /Users/richars/code/universe
  cd /Users/richard/code
  git clone https://github.com/mesosphere/universe --branch=version-3.x
  cd universe
  #cp -R repo/packages/O/openvpn/1
  #sed -i -e 's/mesosphere\/dcos-openvpn/aggress\/dcos-openvpn/g' repo/packages/O/openvpn/1/resource.json
  #sed -i -e 's/0.0.0-0.1/0.0.0-0.2/g' repo/packages/O/openvpn/1/package.json
} 

function build {
  cd /Users/richard/code/universe
  scripts/build.sh
  DOCKER_IMAGE="192.168.33.10:5000/universe-server" DOCKER_TAG="universe-server" docker/server/build.bash
  DOCKER_IMAGE="192.168.33.10:5000/universe-server" DOCKER_TAG="universe-server" docker/server/build.bash publish
  dcos marathon app add /Users/richard/code/universe/docker/server/target/marathon.json
  dcos package repo add --index=0 universe-server http://universe.marathon.mesos:8085/repo
}

function remove {
  dcos package uninstall openvpn
  dcos marathon app remove /universe
  dcos package repo remove universe-server
  docker image rm -f 192.168.33.10:5000/universe-server:universe-server
  docker rmi -f $(docker images -aq)
}

case "$@" in
  remove) remove ;;
  build)  build  ;;
  rebuild_universe)  rebuild_universe  ;;
  *)      echo "build or remove";  exit 1 ;;
esac
