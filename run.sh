#!/bin/bash -e

ss-server -s 0.0.0.0 -p 6000 -k ${PASSWORD:-test} -m aes-256-gcm -u --plugin v2ray-plugin --plugin-opts "server" &
PIDS[0]=$!
ss-manager -m aes-256-gcm -u --plugin v2ray-plugin --plugin-opts "server" --manager-address 127.0.0.1:6000 &
PIDS[1]=$!
ssmgr -c ~/config.yml &
PIDS[2]=$!
ssmgr -c ~/telconf.yml &
PIDS[3]=$!

trap "kill ${PIDS[*]}" SIGINT

wait