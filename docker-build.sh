#!/bin/bash

docker build -t dcos-openvpn .
docker tag dcos-openvpn aggress/dcos-openvpn:$1
docker push aggress/dcos-openvpn:$1
