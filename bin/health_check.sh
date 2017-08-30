#!/bin/sh

# Simple health check for the a running openvpn process

if [ $(pgrep openvpn) ]; then
  exit 0
else
  exit 1
fi

