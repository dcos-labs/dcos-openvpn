#!/bin/bash

echo -e "zk-shell --run-from-stdin master.mesos:2181 << EOF\nadd_auth digest $OVPN_USERNAME:$OVPN_PASSWORD\n$1\nEOF" | sh